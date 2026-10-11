# typed: false
# frozen_string_literal: true

class IdentitySocialCeremonyFinalCommitter
  Commit = Data.define(:transaction, :result, :identity, :user, :existing_account, :pt, :entry)

  public

  def self.call!(result_token:, actor: nil, session_ref:, surface:,
                 ip_address: nil, user_agent: nil, now: Time.current)
    new(
      result_token: result_token,
      actor: actor,
      session_ref: session_ref,
      surface: surface,
      ip_address: ip_address,
      user_agent: user_agent,
      now: now,
    ).call!
  end

  def self.committed_signup!(result_token:, session_ref:, surface:)
    new(result_token:, actor: nil, session_ref:, surface:).committed_signup!
  end

  def initialize(result_token:, actor:, session_ref:, surface:, ip_address: nil, user_agent: nil,
                 now: Time.current)
    @result_token = result_token
    @actor = actor
    @session_ref = session_ref.to_s
    @surface = surface.to_s
    @ip_address = ip_address
    @user_agent = user_agent
    @now = now
  end

  def call!
    validate_binding!
    validate_provider_subject!
    validate_transaction_state!
    return commit_signup! if operation == "signup"

    consumption = IdentitySocialCeremonyResultConsumer.new(transaction: transaction, now: now).call(result_token)
    return commit_login!(consumption) if operation == "login"

    identity = commit_link!
    record_audit!(identity)
    Commit.new(
      transaction: consumption.transaction,
      result: consumption.result,
      identity: identity,
      user: actor,
      existing_account: nil,
      pt: transaction_return_to,
      entry: nil,
    )
  end

  def committed_signup!
    return unless operation == "signup" && transaction.consumed?

    validate_binding!
    validate_committed_signup_receipt!

    @candidate_for_subject = IdentitySocialCeremonyCandidateStore.fetch_consumed!(result["candidate_ref"])
    validate_candidate!(@candidate_for_subject)
    validate_provider_subject!
    flow = ClientSignUpFlow.find_by!(public_id: result["actor_ref"])
    identity = ClientExternalIdentity.where(
      id: flow.pending_contact_id,
      client_id: flow.principal_id,
      provider:,
    ).sole
    user = identity.user
    unless flow.completed? && flow.pending_contact_type == "social_identity" && identity.released_at.nil? &&
        identity.state == "active" && identity.subject == provider_subject && user.login_allowed?
      raise IdentitySocialCeremonyContract::Error, "social completion source is unavailable"
    end

    Commit.new(
      transaction:, result:, identity:, user:, existing_account: false,
      pt: transaction_return_to, entry: transaction_return_entry,
    )
  end

  private

  attr_reader :result_token, :actor, :session_ref, :surface, :ip_address, :user_agent, :now

  def validate_committed_signup_receipt!
    unless !transaction.expired?(now:) && transaction.result_jti == result["result_jti"] &&
        transaction.provider == provider && transaction.operation == operation &&
        transaction.provider_subject_digest == result["provider_subject_digest"]
      raise IdentitySocialCeremonyContract::Error, "social completion receipt does not match"
    end

  end

  def validate_binding!
    raise IdentitySocialCeremonyContract::Error, "session_ref is required" if session_ref.blank?

    if operation == "link"
      raise IdentitySocialCeremonyContract::Error, "actor is required" if actor.blank?
      unless result["actor_ref"].to_s == actor.public_id.to_s
        raise IdentitySocialCeremonyContract::Error, "result actor does not match current actor"
      end
    elsif result["actor_ref"].to_s != transaction.actor_ref.to_s
      raise IdentitySocialCeremonyContract::Error, "result actor does not match transaction"
    end
    raise IdentitySocialCeremonyContract::Error,
          "result session does not match current session" unless result["session_ref"].to_s == session_ref
    raise IdentitySocialCeremonyContract::Error,
          "result surface does not match current surface" unless result["surface"].to_s == surface
  end

  def validate_provider_subject!
    expected = IdentitySocialCeremonyContract.provider_subject_digest(provider: provider, subject: provider_subject)
    raise IdentitySocialCeremonyContract::Error,
          "result provider subject does not match callback" unless result["provider_subject_digest"].to_s ==
            expected
  end

  def validate_transaction_state!
    raise IdentitySocialCeremonyContract::Error, "transaction is expired" if transaction.expired?(now: now)
    raise IdentitySocialCeremonyContract::Error, "transaction is already consumed" if transaction.consumed?
  end

  def commit_link!
    callback_result = candidate_for_subject.callback_result
    SocialAuthLinkHandler.call(
      principal: callback_result.principal,
      credential_candidate: callback_result.credential_candidate,
      current_client: actor,
      repository: identity_repository,
      provider: provider,
      uid: provider_subject,
      ceremony_started_at: transaction.created_at,
    )[:identity]
  end

  def commit_login!(consumption)
    candidate = IdentitySocialCeremonyCandidateStore.consume!(result["candidate_ref"])
    validate_candidate!(candidate)
    callback_result = candidate.callback_result
    decision = ExternalAuthenticationLoginUseCase.call(
      principal: callback_result.principal,
      credential_candidate: callback_result.credential_candidate,
      sign_up_entry: transaction_return_entry == "sign_up",
      ceremony_started_at: transaction.created_at,
    )
    Commit.new(
      transaction: consumption.transaction,
      result: consumption.result,
      identity: decision.identity,
      user: decision.user,
      existing_account: decision.existing_account,
      pt: transaction_return_to,
      entry: transaction_return_entry,
    )
  end

  def commit_signup!
    candidate = candidate_for_subject
    validate_candidate!(candidate)
    birthdate = result["birthdate"].to_s
    raise IdentitySocialCeremonyContract::Error, "birthdate is required" if birthdate.blank?
    raise IdentitySocialCeremonyContract::Error, "birthdate is ineligible" unless
      SignUpEligibilityPolicy.minimum_age_reached?(birthdate, surface: surface, today: Time.zone.today)

    cycle = ClientSignUpFlow.find_by!(public_id: result["actor_ref"])
    cycle.with_cycle_lock do
      cycle.require_active_cycle!
      commit_signup_source!(candidate, birthdate, cycle)
    end
  end

  def commit_signup_source!(candidate, birthdate, cycle)
    AppZenithRecord.connected_to(role: :writing) do
      AppPrincipalRecord.transaction do
        signup = ExternalAuthenticationSignupUseCase.call(
          principal: candidate.callback_result.principal,
          credential_candidate: candidate.callback_result.credential_candidate,
          birthdate: birthdate,
          ceremony_started_at: transaction.created_at,
        )
        signup.user.with_lock do
          AppTicketRecord.connected_to(role: :writing) do
            AppTicketRecord.transaction do
              transaction.lock!
              consumption = IdentitySocialCeremonyResultConsumer.new(
                transaction: transaction,
                now: now,
              ).call(result_token)
              consumed_candidate = IdentitySocialCeremonyCandidateStore.consume!(result["candidate_ref"])
              validate_candidate!(consumed_candidate)
              IdentityGraphProvisioner.call!(surface: :app, principal: signup.user)
              complete_signup_flow!(signup, cycle)
              Commit.new(
                transaction: consumption.transaction, result: consumption.result,
                identity: signup.identity, user: signup.user, existing_account: false,
                pt: transaction_return_to, entry: transaction_return_entry,
              )
            end
          end
        end
      end
    end
  end

  def complete_signup_flow!(signup, cycle)
    cycle.with_cycle_lock do
      cycle.update!(
        principal_id: signup.user.id,
        pending_contact_type: "social_identity",
        pending_contact_id: signup.identity.id,
        social_provider: SocialIdentifiable.normalize_provider(signup.identity.provider),
      )
      finalized = SignUpStateMachine.call(
        ticket: cycle, event: :finalize, actor_context: Actor.authn,
        payload: { finalization_result: :accepted },
      )
      raise IdentitySocialCeremonyContract::Error, "social signup finalization refused" unless finalized.success?

      completed = SignUpStateMachine.call(ticket: cycle, event: :complete, actor_context: Actor.authn)
      raise IdentitySocialCeremonyContract::Error, "social signup completion refused" unless completed.success?
    end
  end

  def validate_candidate!(candidate)
    raise IdentitySocialCeremonyContract::Error, "result candidate is required" if candidate.blank?
    raise IdentitySocialCeremonyContract::Error,
          "result candidate digest does not match" unless result["candidate_digest"].to_s == candidate.digest
    raise IdentitySocialCeremonyContract::Error,
          "candidate surface does not match" unless candidate.surface.to_s == surface
    raise IdentitySocialCeremonyContract::Error,
          "candidate actor does not match" unless candidate.actor_ref.to_s == result["actor_ref"].to_s
    raise IdentitySocialCeremonyContract::Error,
          "candidate session does not match" unless candidate.session_ref.to_s == session_ref
    raise IdentitySocialCeremonyContract::Error,
          "candidate transaction does not match" unless candidate.transaction_id.to_s ==
            transaction.transaction_id.to_s
    raise IdentitySocialCeremonyContract::Error,
          "candidate operation does not match" unless candidate.operation.to_s == operation
    raise IdentitySocialCeremonyContract::Error,
          "candidate provider does not match" unless candidate.provider.to_s == provider
  end

  def record_audit!(identity)
    return if identity.blank?

    Rails.logger.info(
      JitLogEvent.format(
        "identity.social_ceremony.link_committed",
        user_id: actor.id,
        provider: SocialIdentifiable.normalize_provider(provider),
      ),
    )
  end

  def result
    @result ||= IdentitySocialCeremonyResult.decode(
      result_token,
      issuer_id: IdentitySocialCeremonyContract.sign_issuer_id(surface), now: now,
    )
  end

  def transaction
    @transaction ||= IdentitySocialCeremonyReplayStore.for(surface).find_transaction!(result["transaction_id"])
  end

  def provider
    @provider ||= result["provider"].to_s
  end

  def provider_subject
    @provider_subject ||= candidate_for_subject.callback_result.principal.subject
  end

  def identity_repository
    @identity_repository ||= ExternalAuthentication::IdentityRepositoryFactory.current.build(provider)
  end

  def operation
    @operation ||= result["operation"].to_s
  end

  def candidate_for_subject
    @candidate_for_subject ||= IdentitySocialCeremonyCandidateStore.fetch!(result["candidate_ref"])
  end

  def transaction_return_to
    transaction.respond_to?(:return_to) ? transaction.return_to.presence : nil
  end

  def transaction_return_entry
    transaction.respond_to?(:resource_ref) ? transaction.resource_ref.presence : nil
  end
end
