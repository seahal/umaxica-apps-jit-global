# typed: false
# frozen_string_literal: true

class IdentitySecretCredentialCeremonyFinalCommitter
  CONFIG = {
    "com" => {
      record_class: VisitorSecretCredential,
      owner_association: :visitor_secret_credentials,
      status_key: :visitor_secret_credential_status_id,
      active_status_id: VisitorSecretCredentialStatus::ACTIVE,
      revoked_status_id: VisitorSecretCredentialStatus::REVOKED,
      max_count: VisitorSecretCredential::MAX_SECRETS_PER_VISITOR,
    },
    "org" => {
      record_class: OperatorSecretCredential,
      owner_association: :staff_secret_credentials,
      status_key: :staff_identity_secret_status_id,
      active_status_id: OperatorSecretCredentialStatus::ACTIVE,
      revoked_status_id: OperatorSecretCredentialStatus::REVOKED,
      max_count: OperatorSecretCredential::MAX_SECRETS_PER_STAFF,
      audit_event_id: OperatorChronicleEvent::STAFF_SECRET_CREATED,
      audit_action: OperatorSecretCredentialsCreate::ACTION,
    },
  }.freeze

  Commit = Data.define(:transaction, :result, :secret_credential)

  def self.call!(result_token:, actor:, session_ref:, surface:, ip_address: nil, user_agent: nil, now: Time.current)
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

  def initialize(result_token:, actor:, session_ref:, surface:, ip_address: nil, user_agent: nil, now: Time.current)
    @result_token = result_token
    @actor = actor
    @session_ref = session_ref.to_s
    @surface = surface.to_s
    @ip_address = ip_address
    @user_agent = user_agent
    @now = now
  end

  def call!
    config
    validate_actor_binding!
    validate_transaction_state!
    candidate = fetch_candidate!
    validate_enrollment_policy!
    consumption = IdentitySecretCredentialCeremonyResultConsumer.new(
      transaction: transaction,
      now: now,
    ).call(result_token)
    secret_credential = commit_secret_credential!(candidate)
    IdentitySecretCredentialCeremonyCandidateStore.delete(candidate.ref)
    record_audit!(secret_credential)
    Commit.new(
      transaction: consumption.transaction, result: consumption.result,
      secret_credential: secret_credential,
    )
  end

  private

  attr_reader :result_token, :actor, :session_ref, :surface, :ip_address, :user_agent, :now

  def validate_actor_binding!
    raise IdentitySecretCredentialCeremonyContract::Error, "actor is required" if actor.blank?
    raise IdentitySecretCredentialCeremonyContract::Error, "session_ref is required" if session_ref.blank?
    raise IdentitySecretCredentialCeremonyContract::Error,
          "result actor does not match current actor" unless result["actor_ref"].to_s == actor.public_id.to_s
    raise IdentitySecretCredentialCeremonyContract::Error,
          "result session does not match current session" unless result["session_ref"].to_s == session_ref
    raise IdentitySecretCredentialCeremonyContract::Error,
          "result surface does not match current surface" unless result["surface"].to_s == surface
  end

  def validate_transaction_state!
    raise IdentitySecretCredentialCeremonyContract::Error, "transaction is expired" if transaction.expired?(now: now)
    raise IdentitySecretCredentialCeremonyContract::Error, "transaction is already consumed" if transaction.consumed?
  end

  def fetch_candidate!
    candidate = IdentitySecretCredentialCeremonyCandidateStore.fetch!(result["credential_candidate_ref"])
    raise IdentitySecretCredentialCeremonyContract::Error,
          "candidate digest does not match result" unless candidate.digest.to_s ==
            result["credential_candidate_digest"].to_s
    raise IdentitySecretCredentialCeremonyContract::Error,
          "candidate actor does not match current actor" unless candidate.actor_ref.to_s == actor.public_id.to_s
    raise IdentitySecretCredentialCeremonyContract::Error,
          "candidate session does not match current session" unless candidate.session_ref.to_s == session_ref
    raise IdentitySecretCredentialCeremonyContract::Error,
          "candidate surface does not match current surface" unless candidate.surface.to_s == surface
    raise IdentitySecretCredentialCeremonyContract::Error,
          "candidate transaction does not match result" unless candidate.transaction_id.to_s ==
            result["transaction_id"].to_s
    raise IdentitySecretCredentialCeremonyContract::Error,
          "candidate operation does not match result" unless candidate.operation.to_s ==
            result["operation"].to_s

    candidate
  end

  def validate_enrollment_policy!
    return if result["operation"].to_s == "enrollment"

    raise IdentitySecretCredentialCeremonyContract::Error, "operation is invalid"
  end

  def commit_secret_credential!(candidate)
    raise IdentitySecretCredentialCeremonyContract::Error,
          "secret credential limit is reached" if secret_credentials.count >= config.fetch(:max_count)

    config.fetch(:record_class).transaction do
      secret_credentials.create!(
        :name => candidate.name,
        :password_digest => candidate.password_digest,
        config.fetch(:status_key) => candidate.enabled ? config.fetch(:active_status_id) :
                                                          config.fetch(:revoked_status_id),
      )
    end
  rescue ActiveRecord::RecordInvalid => e
    raise IdentitySecretCredentialCeremonyContract::Error,
          "secret credential commit failed: #{e.record.errors.full_messages.join(", ")}"
  end

  def record_audit!(secret_credential)
    return if config[:audit_event_id].blank?

    IdentityAudit.record!(
      actor: actor,
      subject: secret_credential,
      event_id: config.fetch(:audit_event_id),
      action: config.fetch(:audit_action),
      ip_address: ip_address,
      user_agent: user_agent,
    )
  end

  def secret_credentials
    actor.public_send(config.fetch(:owner_association))
  end

  def result
    @result ||= IdentitySecretCredentialCeremonyResult.decode(
      result_token,
      issuer_id: IdentitySecretCredentialCeremonyContract.sign_issuer_id(surface), now: now,
    )
  end

  def transaction
    @transaction ||= IdentitySecretCredentialCeremonyReplayStore.for(surface)
      .find_transaction!(result["transaction_id"])
  end

  def config
    CONFIG.fetch(surface) { raise IdentitySecretCredentialCeremonyContract::Error, "surface is invalid" }
  end
end
