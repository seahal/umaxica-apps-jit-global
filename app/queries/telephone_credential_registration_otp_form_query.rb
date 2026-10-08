# frozen_string_literal: true

class TelephoneCredentialRegistrationOtpFormQuery
  class << self
    public

    def call(actor:, token:, telephone:, transaction:, browser_nonce:)
      return false unless actor && token && telephone && transaction && browser_nonce.is_a?(String) &&
        browser_nonce.encoding.ascii_compatible? && browser_nonce.valid_encoding? &&
        browser_nonce.match?(/\A[A-Za-z0-9_-]{43}\z/)

      new(actor: actor, token: token, telephone: telephone, transaction: transaction, browser_nonce: browser_nonce).call
    end
  end

  public

  def initialize(actor:, token:, telephone:, transaction:, browser_nonce:)
    @actor, @token, @telephone, @transaction, @browser_nonce = actor, token, telephone, transaction, browser_nonce
    @surface =
      case [actor, token, telephone, transaction]
      in [Client, ClientToken, ClientTelephone, ClientTelephoneCeremonyTransaction] then "app"
      in [Visitor, VisitorToken, VisitorTelephone, VisitorTelephoneCeremonyTransaction] then "com"
      in [Operator, OperatorToken, OperatorTelephone, OperatorTelephoneCeremonyTransaction] then "org"
      else raise ArgumentError, "unsupported Telephone registration form realm"
      end
  end

  def call
    now = transaction.class.database_now
    source_current? && root_current?(now) && ticket_current?(now) && available_evidence?(now)
  end

  private

  attr_reader :actor, :token, :telephone, :transaction, :browser_nonce, :surface

  def source_current?
    source_owned? && actor.login_allowed? && actor.accessible?(actor.class.database_now) && source_available?
  end

  def source_owned?
    case actor
    when Client
      token.user_id == actor.id && telephone.user_id == actor.id && token.device_session.user_id == actor.id
    when Visitor
      token.visitor_id == actor.id && telephone.visitor_id == actor.id && token.device_session.visitor_id == actor.id
    when Operator
      token.staff_id == actor.id && telephone.staff_id == actor.id && token.device_session.staff_id == actor.id
    end
  end

  def source_available?
    case telephone
    when ClientTelephone, VisitorTelephone
      telephone.accessible?(telephone.class.database_now) && !telephone.binding_released?
    when OperatorTelephone
      [OperatorTelephoneStatus::UNVERIFIED, OperatorTelephoneStatus::VERIFIED].include?(telephone.staff_telephone_status_id)
    end
  end

  def candidate_ref
    case telephone
    when ClientTelephone, VisitorTelephone then telephone.public_id
    when OperatorTelephone then telephone.id.to_s
    end
  end

  def root_current?(now)
    token.currently_usable?(now) && token.device_session.usable? &&
      token.device_session.current_refresh_token_id == token.id
  end

  def ticket_current?(now)
    expected = CredentialRegistrationOtpSessionValue.for(
      surface: surface, channel: :telephone, transaction_ref: transaction.transaction_id,
      root_ref: token.public_id, browser_nonce: browser_nonce,
    ).dump
    transaction.surface == surface && transaction.actor_ref == actor.public_id &&
      transaction.session_ref == expected && transaction.operation == "registration" &&
      transaction.purpose == "credential_registration" && transaction.telephone_candidate_ref == candidate_ref &&
      transaction.normalized_number_digest == telephone.number_digest && transaction.status == "pending" &&
      !transaction.consumed_at && transaction.expires_at > now && !transaction.otp_cancelled_at
  end

  def available_evidence?(now)
    return true if transaction.telephone_otp_deliverable?(generation: transaction.otp_generation, at: now)

    transaction.otp_consumed_at && transaction.otp_consumed_at <= now && transaction.otp_receipt_verifier.present? &&
      transaction.otp_result_expires_at && transaction.otp_result_expires_at > now
  end
end
