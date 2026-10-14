# frozen_string_literal: true

class EmailCredentialRegistrationOtpVerificationCommitter
  class << self
    public

    def call(**arguments)
      new(**arguments).call
    end
  end

  public

  def initialize(actor:, token:, email:, transaction:, browser_nonce:, code:)
    @actor, @token, @email, @transaction, @browser_nonce, @code = actor, token, email, transaction, browser_nonce, code
    @surface, @pending_status, @bootstrap_model =
      case [actor, token, email, transaction]
      in [Client, ClientToken, ClientEmail, ClientEmailCeremonyTransaction]
        ["app", ClientEmailStatus::UNVERIFIED, ClientStepUpCeremonyTransaction]
      in [Visitor, VisitorToken, VisitorEmail, VisitorEmailCeremonyTransaction]
        ["com", VisitorEmailStatus::UNVERIFIED, VisitorStepUpCeremonyTransaction]
      in [Operator, OperatorToken, OperatorEmail, OperatorEmailCeremonyTransaction]
        ["org", OperatorEmailStatus::UNVERIFIED, OperatorStepUpCeremonyTransaction]
      else raise ArgumentError, "unsupported Email registration verification realm"
      end
  end

  def call
    return result(:invalid_code) unless ascii_match?(code, /\A[0-9]{6}\z/)
    return result(:session_mismatch) unless ascii_match?(browser_nonce, /\A[A-Za-z0-9_-]{43}\z/)

    @session_ref = CredentialRegistrationOtpSessionValue.for(
      surface: surface, channel: :email, transaction_ref: transaction.transaction_id,
      root_ref: token.public_id, browser_nonce: browser_nonce,
    ).dump
    source_snapshot = nil
    verification =
      with_locks do
        next result(:session_mismatch) unless transaction.session_ref == session_ref
        next result(:unavailable) unless current_authority?
        next result(:locked) if email.locked?(now: email.class.database_now)

        outcome = transaction.otp_consumed_at ? verify_receipt : verify_challenge
        source_snapshot = email.attributes.slice("otp_attempts_count", "locked_at", "updated_at") if outcome.success?
        outcome
      end
    return verification unless verification.success?

    with_locks do
      next result(:unavailable) unless current_authority? && verified_receipt?

      if email.attributes.slice(*source_snapshot.keys) == source_snapshot
        email.update!(otp_attempts_count: 0, locked_at: EmailOtpPolicy::OTP_UNLOCKED_SENTINEL)
      end
      result(:verified)
    end
  end

  private

  attr_reader :actor, :token, :email, :transaction, :browser_nonce, :code, :surface, :pending_status, :session_ref,
              :bootstrap_model, :bootstrap_parent, :bootstrap_session

  def with_locks
    actor.class.connection_class_for_self.connected_to(role: :writing) do
      actor.with_lock do
        transaction.class.connection_owner.connected_to(role: :writing) do
          token_device_session.with_lock do
            token.with_lock do
              email.with_lock do
                transaction.reload
                reference = transaction.bootstrap_ceremony_transaction_ref
                if reference
                  @bootstrap_parent = bootstrap_model.find_by(transaction_id: reference)
                  next result(:unavailable) unless bootstrap_parent

                  EmailCredentialRegistrationBootstrapGuard.call(
                    actor: actor, token: token, bootstrap_transaction: bootstrap_parent, browser_nonce: browser_nonce,
                  ) do |_, session|
                    @bootstrap_session = session
                    transaction.with_lock { yield }
                  end || result(:unavailable)
                else
                  @bootstrap_parent = @bootstrap_session = nil
                  transaction.with_lock { yield }
                end
              end
            end
          end
        end
      end
    end
  end

  def current_authority?
    ticket_now = transaction.class.database_now
    source_now = email.class.database_now
    source_owned? && actor.login_allowed? && actor.accessible?(source_now) &&
      source_binding_available?(source_now) && root_current?(ticket_now) && ticket_current?(ticket_now) &&
      original_bootstrap_current?(ticket_now)
  end

  def original_bootstrap_current?(now)
    return transaction.bootstrap_ceremony_transaction_ref.nil? unless bootstrap_parent

    transaction.bootstrap_ceremony_transaction_ref == bootstrap_parent.transaction_id &&
      bootstrap_parent.status == "pending" && bootstrap_parent.expires_at > now &&
      bootstrap_session.status == "PENDING" && bootstrap_session.discard_at > now
  end

  def source_owned?
    case actor
    when Client
      token.user_id == actor.id && token_device_session.user_id == actor.id && email.user_id == actor.id
    when Visitor
      token.visitor_id == actor.id && token_device_session.visitor_id == actor.id && email.visitor_id == actor.id
    when Operator
      token.staff_id == actor.id && token_device_session.staff_id == actor.id && email.staff_id == actor.id
    end
  end

  def root_current?(now)
    token.currently_usable?(now) && token_device_session.usable? &&
      token_device_session.current_refresh_token_id == token.id
  end

  def token_device_session
    @token_device_session ||= token.device_session_record!
  end

  def ticket_current?(now)
    transaction.surface == surface &&
      transaction.actor_ref == actor.public_id && transaction.session_ref == session_ref &&
      transaction.operation == "registration" && transaction.purpose == "credential_registration" &&
      transaction.email_candidate_ref == email.public_id &&
      transaction.normalized_email_digest == email.address_digest &&
      transaction.status == "pending" && !transaction.consumed_at && transaction.expires_at > now &&
      !transaction.otp_cancelled_at
  end

  def verify_challenge
    pending =
      case email
      when ClientEmail then email.user_email_status_id == pending_status
      when VisitorEmail then email.visitor_email_status_id == pending_status
      when OperatorEmail then email.staff_email_status_id == pending_status
      end
    return result(:unavailable) unless pending && source_unfinalized?

    admission = nil
    verified =
      transaction.verify_email_otp!(code: code, **proof_binding) do |valid|
        admission = admit_code(valid)
        admission == :verified && current_authority?
      end
    return result(:locked) if admission == :locked || email.locked?(now: email.class.database_now)

    result(verified ? :verified : :invalid_code)
  end

  def source_binding_available?(now)
    case email
    when ClientEmail, VisitorEmail then email.accessible?(now) && !email.binding_released?
    when OperatorEmail
      [OperatorEmailStatus::UNVERIFIED, OperatorEmailStatus::VERIFIED].include?(email.staff_email_status_id)
    else raise ArgumentError, "unsupported Email registration candidate"
    end
  end

  def source_unfinalized?
    case email
    when ClientEmail, VisitorEmail then !email.binding_finalized_at
    when OperatorEmail then email.staff_email_status_id == pending_status
    else raise ArgumentError, "unsupported Email registration candidate"
    end
  end

  def verify_receipt
    deadline = transaction.otp_result_expires_at
    return result(:result_expired) unless deadline && deadline > transaction.class.database_now

    valid = verified_receipt?
    admission = admit_code(valid)
    return result(:locked) if admission == :locked || email.locked?(now: email.class.database_now)
    return result(:invalid_code) unless valid
    return result(:result_expired) unless current_authority? && verified_receipt?

    result(:already_verified)
  end

  def verified_receipt?
    transaction.email_otp_verified_evidence?(code: code, **proof_binding)
  end

  def admit_code(valid)
    admission = EmailOtpVerificationFailureBudget.new.verify!(
      surface: surface.to_sym, purpose: :credential_registration, channel: :email,
      destination_digest: email.address_digest, valid: valid,
    )
    email.increment_attempts! unless valid
    admission
  end

  def proof_binding
    { purpose: "credential_registration",
      actor_ref: actor.public_id,
      session_ref: session_ref,
      operation: "registration",
      candidate_ref: email.public_id, }
  end

  def ascii_match?(value, pattern)
    value.is_a?(String) && value.encoding.ascii_compatible? && value.valid_encoding? && value.match?(pattern)
  end

  def result(status)
    EmailCredentialRegistrationOtpVerificationResult.new(status: status, email: email)
  end
end
