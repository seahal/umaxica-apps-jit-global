# frozen_string_literal: true

class TelephoneCredentialRegistrationOtpResendIssuer
  class << self
    public

    def call(**arguments)
      new(**arguments).call
    end
  end

  public

  def initialize(actor:, token:, telephone:, transaction:, browser_nonce:)
    @actor, @token, @telephone, @transaction, @browser_nonce = actor, token, telephone, transaction, browser_nonce
    @surface, @pending_status =
      case [actor, token, telephone, transaction]
      in [Client, ClientToken, ClientTelephone, ClientTelephoneCeremonyTransaction]
        ["app", ClientTelephoneStatus::UNVERIFIED]
      in [Visitor, VisitorToken, VisitorTelephone, VisitorTelephoneCeremonyTransaction]
        ["com", VisitorTelephoneStatus::UNVERIFIED]
      in [Operator, OperatorToken, OperatorTelephone, OperatorTelephoneCeremonyTransaction]
        ["org", OperatorTelephoneStatus::UNVERIFIED]
      else raise ArgumentError, "unsupported Telephone registration resend realm"
      end
  end

  def call
    expected = CredentialRegistrationOtpSessionValue.for(
      surface: surface, channel: :telephone, transaction_ref: transaction.transaction_id,
      root_ref: token.public_id, browser_nonce: browser_nonce,
    ).dump
    return result(:unavailable) unless transaction.session_ref == expected

    actor.class.connection_class_for_self.connected_to(role: :writing) do
      actor.with_lock do
        transaction.class.connection_owner.connected_to(role: :writing) do
          token.device_session.with_lock do
            token.with_lock do
              telephone.with_lock do
                transaction.with_lock { resend_locked(expected) }
              end
            end
          end
        end
      end
    end
  end

  private

  attr_reader :actor, :token, :telephone, :transaction, :browser_nonce, :surface, :pending_status

  def resend_locked(expected)
    ticket_now = transaction.class.database_now
    source_now = telephone.class.database_now
    return result(:unavailable) unless source_current?(source_now) && root_current?(ticket_now) &&
      ticket_current?(expected, ticket_now)
    return result(:locked) if telephone.locked?(now: source_now)

    code = transaction.reissue_telephone_otp!
    telephone.update!(otp_last_sent_at: source_now)
    TelephoneCredentialRegistrationOtpIssueResult.new(status: :issued, transaction: transaction, code: code.freeze)
  end

  def source_current?(now)
    available =
      case telephone
      when ClientTelephone, VisitorTelephone
        telephone.accessible?(now) && !telephone.binding_finalized_at && !telephone.binding_released?
      when OperatorTelephone then telephone.staff_telephone_status_id == pending_status
      end
    owned_pending? && available && actor.login_allowed? && actor.accessible?(now)
  end

  def owned_pending?
    owner_id = actor.id
    case actor
    when Client
      token.user_id == owner_id && token.device_session.user_id == owner_id && telephone.user_id == owner_id &&
        telephone.user_telephone_status_id == pending_status
    when Visitor
      token.visitor_id == owner_id && token.device_session.visitor_id == owner_id &&
        telephone.visitor_id == owner_id && telephone.visitor_telephone_status_id == pending_status
    when Operator
      token.staff_id == owner_id && token.device_session.staff_id == owner_id && telephone.staff_id == owner_id &&
        telephone.staff_telephone_status_id == pending_status
    end
  end

  def root_current?(now)
    token.currently_usable?(now) && token.device_session.usable? &&
      token.device_session.current_refresh_token_id == token.id
  end

  def ticket_current?(expected, now)
    candidate =
      case telephone
      when ClientTelephone, VisitorTelephone then telephone.public_id
      when OperatorTelephone then telephone.id.to_s
      end
    transaction.surface == surface && transaction.actor_ref == actor.public_id && transaction.session_ref == expected &&
      transaction.operation == "registration" && transaction.purpose == "credential_registration" &&
      transaction.telephone_candidate_ref == candidate &&
      transaction.normalized_number_digest == telephone.number_digest &&
      transaction.telephone_otp_deliverable?(generation: transaction.otp_generation, at: now)
  end

  def result(status)
    TelephoneCredentialRegistrationOtpIssueResult.new(status: status, transaction: nil, code: nil)
  end
end
