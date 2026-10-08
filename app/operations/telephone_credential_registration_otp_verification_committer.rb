# frozen_string_literal: true

class TelephoneCredentialRegistrationOtpVerificationCommitter
  class << self
    public

    def call(**arguments)
      new(**arguments).call
    end
  end

  public

  def initialize(actor:, token:, telephone:, transaction:, browser_nonce:, code:)
    @actor, @token, @telephone, @transaction, @browser_nonce, @code =
      actor, token, telephone, transaction, browser_nonce, code
    @surface, @pending_status =
      case [actor, token, telephone, transaction]
      in [Client, ClientToken, ClientTelephone, ClientTelephoneCeremonyTransaction]
        ["app", ClientTelephoneStatus::UNVERIFIED]
      in [Visitor, VisitorToken, VisitorTelephone, VisitorTelephoneCeremonyTransaction]
        ["com", VisitorTelephoneStatus::UNVERIFIED]
      in [Operator, OperatorToken, OperatorTelephone, OperatorTelephoneCeremonyTransaction]
        ["org", OperatorTelephoneStatus::UNVERIFIED]
      else raise ArgumentError, "unsupported Telephone registration verification realm"
      end
  end

  def call
    return result(:invalid_code) unless ascii_match?(code, /\A[0-9]{6}\z/)
    return result(:session_mismatch) unless ascii_match?(browser_nonce, /\A[A-Za-z0-9_-]{43}\z/)

    @session_ref = CredentialRegistrationOtpSessionValue.for(
      surface: surface, channel: :telephone, transaction_ref: transaction.transaction_id,
      root_ref: token.public_id, browser_nonce: browser_nonce,
    ).dump
    snapshot = nil
    verification =
      with_locks do
        next result(:session_mismatch) unless transaction.session_ref == session_ref
        next result(:unavailable) unless current_authority?
        next result(:locked) if telephone.locked?(now: telephone.class.database_now)

        outcome = transaction.otp_consumed_at ? verify_receipt : verify_challenge
        snapshot = telephone.attributes.slice("otp_attempts_count", "locked_at", "updated_at") if outcome.success?
        outcome
      end
    return verification unless verification.success?

    with_locks do
      next result(:unavailable) unless current_authority? && verified_receipt?

      if telephone.attributes.slice(*snapshot.keys) == snapshot
        telephone.update!(otp_attempts_count: 0, locked_at: TelephoneOtpPolicy::OTP_UNLOCKED_SENTINEL)
      end
      result(:verified)
    end
  end

  private

  attr_reader :actor, :token, :telephone, :transaction, :browser_nonce, :code, :surface, :pending_status, :session_ref

  def with_locks
    actor.class.connection_class_for_self.connected_to(role: :writing) do
      actor.with_lock do
        transaction.class.connection_owner.connected_to(role: :writing) do
          token.device_session.with_lock do
            token.with_lock do
              telephone.with_lock do
                transaction.with_lock { yield }
              end
            end
          end
        end
      end
    end
  end

  def current_authority?
    now = transaction.class.database_now
    source_now = telephone.class.database_now
    source_owned? && actor.login_allowed? && actor.accessible?(source_now) && source_current?(source_now) &&
      token.currently_usable?(now) && token.device_session.usable? &&
      token.device_session.current_refresh_token_id == token.id && ticket_current?(now)
  end

  def source_owned?
    case actor
    when Client
      token.user_id == actor.id && token.device_session.user_id == actor.id && telephone.user_id == actor.id
    when Visitor
      token.visitor_id == actor.id && token.device_session.visitor_id == actor.id && telephone.visitor_id == actor.id
    when Operator
      token.staff_id == actor.id && token.device_session.staff_id == actor.id && telephone.staff_id == actor.id
    end
  end

  def ticket_current?(now)
    transaction.surface == surface &&
      transaction.actor_ref == actor.public_id && transaction.session_ref == session_ref &&
      transaction.operation == "registration" && transaction.purpose == "credential_registration" &&
      transaction.telephone_candidate_ref == candidate_ref &&
      transaction.normalized_number_digest == telephone.number_digest && transaction.status == "pending" &&
      !transaction.consumed_at && transaction.expires_at > now && !transaction.otp_cancelled_at
  end

  def verify_challenge
    pending =
      case telephone
      when ClientTelephone then telephone.user_telephone_status_id == pending_status
      when VisitorTelephone then telephone.visitor_telephone_status_id == pending_status
      when OperatorTelephone then telephone.staff_telephone_status_id == pending_status
      end
    return result(:unavailable) unless pending && source_unfinalized?

    admission = nil
    verified =
      transaction.verify_telephone_otp!(code: code, **proof_binding) do |valid|
        admission = admit_code(valid)
        admission == :verified && current_authority?
      end
    return result(:locked) if admission == :locked || telephone.locked?(now: telephone.class.database_now)

    result(verified ? :verified : :invalid_code)
  end

  def verify_receipt
    deadline = transaction.otp_result_expires_at
    return result(:result_expired) unless deadline && deadline > transaction.class.database_now

    valid = verified_receipt?
    admission = admit_code(valid)
    return result(:locked) if admission == :locked || telephone.locked?(now: telephone.class.database_now)
    return result(:invalid_code) unless valid
    return result(:result_expired) unless current_authority? && verified_receipt?

    result(:already_verified)
  end

  def verified_receipt?
    transaction.telephone_otp_verified_evidence?(code: code, **proof_binding)
  end

  def admit_code(valid)
    admission = TelephoneOtpVerificationFailureBudget.new.verify!(
      surface: surface.to_sym, purpose: :credential_registration, channel: :telephone,
      destination_digest: telephone.number_digest, valid: valid,
    )
    telephone.increment_attempts! unless valid
    admission
  end

  def proof_binding
    { purpose: "credential_registration",
      actor_ref: actor.public_id,
      session_ref: session_ref,
      operation: "registration",
      candidate_ref: candidate_ref, }
  end

  def candidate_ref
    case telephone
    when ClientTelephone, VisitorTelephone then telephone.public_id
    when OperatorTelephone then telephone.id.to_s
    end
  end

  def source_current?(now)
    case telephone
    when ClientTelephone, VisitorTelephone then telephone.accessible?(now) && !telephone.binding_released?
    when OperatorTelephone
      [OperatorTelephoneStatus::UNVERIFIED, OperatorTelephoneStatus::VERIFIED].include?(telephone.staff_telephone_status_id)
    end
  end

  def source_unfinalized?
    case telephone
    when ClientTelephone, VisitorTelephone then !telephone.binding_finalized_at
    when OperatorTelephone then telephone.staff_telephone_status_id == pending_status
    end
  end

  def ascii_match?(value, pattern)
    value.is_a?(String) && value.encoding.ascii_compatible? && value.valid_encoding? && value.match?(pattern)
  end

  def result(status)
    TelephoneCredentialRegistrationOtpVerificationResult.new(status: status, telephone: telephone)
  end
end
