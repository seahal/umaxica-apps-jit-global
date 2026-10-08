# frozen_string_literal: true

class OperatorEmailRegistrationOtpFinalizer
  class << self
    public

    def call!(**arguments)
      new(**arguments).call!
    end
  end

  public

  def initialize(actor:, actor_context:, token:, email:, transaction:, browser_nonce:, code:, requirement:)
    unless actor.is_a?(Operator) && token.is_a?(OperatorToken) && email.is_a?(OperatorEmail) &&
        transaction.is_a?(OperatorEmailCeremonyTransaction)
      raise ArgumentError, "ORG Email finalization requires its own realm"
    end

    @actor, @actor_context, @token, @email = actor, actor_context, token, email
    @transaction, @browser_nonce, @code, @requirement = transaction, browser_nonce, code, requirement
  end

  def call!
    return :unavailable unless browser_nonce.is_a?(String) && browser_nonce.encoding.ascii_compatible? &&
      browser_nonce.valid_encoding? && browser_nonce.match?(/\A[A-Za-z0-9_-]{43}\z/)

    session_ref = CredentialRegistrationOtpSessionValue.for(
      surface: "org", channel: :email, transaction_ref: transaction.transaction_id,
      root_ref: token.public_id, browser_nonce: browser_nonce,
    ).dump
    OrgTicketRecord.connected_to(role: :writing) do
      OrgTicketRecord.transaction do
        committed = finalize_source(session_ref)
        return :unavailable unless committed

        transaction.consume_registration_result! unless transaction.consumed?
        :finalized
      end
    end
  end

  private

  attr_reader :actor, :actor_context, :token, :email, :transaction, :browser_nonce, :code, :requirement

  def finalize_source(session_ref)
    Operator.connection_class_for_self.connected_to(role: :writing) do
      actor.with_lock do
        token.device_session.with_lock do
          token.with_lock do
            email.with_lock do
              transaction.with_lock do
                next false unless current_authority?(session_ref)

                email.finalize_email_registration!(transaction: transaction, code: code, session_ref: session_ref)
                true
              end
            end
          end
        end
      end
    end
  end

  def current_authority?(session_ref)
    context_matches? && current_policy? && source_current? && root_current? && bound_evidence?(session_ref)
  end

  def source_current?
    actor.login_allowed? && actor.accessible?(Operator.database_now) &&
      token.staff_id == actor.id && token.device_session.staff_id == actor.id && email.staff_id == actor.id
  end

  def root_current?
    now = OperatorEmailCeremonyTransaction.database_now
    token.currently_usable?(now) && token.device_session.usable? &&
      token.device_session.current_refresh_token_id == token.id
  end

  def current_policy?
    policy = OperatorEmailPolicy.new(email, user: actor)
    current_passkey? &&
      requirement.is_a?(StepUpRequirement) &&
      requirement.to_h == policy.credential_registration_requirement(token: token).to_h &&
      policy.create? && policy.update? && StepUpResolver.call(
        token: token, requirement: requirement, now: OperatorEmailCeremonyTransaction.database_now,
      ).satisfied?
  end

  def bound_evidence?(session_ref)
    transaction.surface == "org" && transaction.bootstrap_ceremony_transaction_ref.nil? &&
      transaction.normalized_email_digest == email.address_digest && transaction.email_registration_otp_evidence?(
        code: code, actor_ref: actor.public_id, session_ref: session_ref, candidate_ref: email.public_id,
      )
  end

  def context_matches?
    actor_context.is_a?(ActorValuesContext) && actor_context.subject == actor &&
      actor_context.actor_type == :operator &&
      actor_context.tld.to_s == "org" && actor_context.surface == :base
  end

  def current_passkey?
    token.last_step_up_method == "passkey" && actor.operator_passkeys.active.lock.exists?(
      external_id: token.last_step_up_credential_ref,
    )
  end
end
