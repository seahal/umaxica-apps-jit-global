# frozen_string_literal: true

class ContactRegistrationOtpResendIssuer
  Issuance = Data.define(:code, :counter, :transaction)

  class << self
    public

    def call!(**arguments)
      new(**arguments).call!
    end
  end

  public

  def initialize(actor:, token:, contact:, transaction:, channel:, browser_nonce:)
    @actor = actor
    @token = token
    @contact = contact
    @transaction = transaction
    @channel = channel
    @browser_nonce = browser_nonce
    @surface =
      case [actor, token, contact, transaction, channel]
      in [Client, ClientToken, ClientEmail, ClientEmailCeremonyTransaction, :email] |
         [Client, ClientToken, ClientTelephone, ClientTelephoneCeremonyTransaction, :telephone] then "app"
      in [Visitor, VisitorToken, VisitorEmail, VisitorEmailCeremonyTransaction, :email] |
         [Visitor, VisitorToken, VisitorTelephone, VisitorTelephoneCeremonyTransaction, :telephone] then "com"
      else raise ArgumentError, "unsupported Contact resend binding"
      end
  end

  def call!
    return :unavailable unless browser_nonce.is_a?(String) && browser_nonce.match?(/\A[A-Za-z0-9_-]{43}\z/)

    actor.class.connection_class_for_self.connected_to(role: :writing) do
      actor.with_lock do
        transaction.class.connection_owner.connected_to(role: :writing) do
          token.device_session.with_lock do
            token.with_lock do
              transaction.with_lock do
                contact.with_lock { resend_under_locks! }
              end
            end
          end
        end
      end
    end
  end

  private

  attr_reader :actor, :token, :contact, :transaction, :channel, :browser_nonce, :surface

  def resend_under_locks!
    ticket_now = transaction.class.database_now
    source_now = contact.class.database_now
    context = contact.credential_registration_otp_context
    return :unavailable unless context && authority_matches?(context, ticket_now, source_now)
    return :unavailable if context.fetch("verified_at") || context.fetch("result_expires_at")

    deadline = Time.iso8601(context.fetch("expires_at"))
    return :unavailable if deadline <= source_now || deadline > transaction.expires_at ||
      deadline > contact.otp_expires_at
    return :locked if contact.locked?(now: source_now)
    return :cooldown if channel == :email && contact.otp_cooldown_active?(now: source_now)

    otp = contact.get_otp
    return :unavailable unless otp && issuance_matches?(context, otp)

    counter = otp.fetch(:otp_counter) + 1
    raise RangeError, "registration OTP counter exhausted" if counter >= (1 << 64)

    replace_issuance!(context, counter, deadline, source_now)
  end

  def authority_matches?(context, ticket_now, source_now)
    source_authority_live?(source_now) && root_authority_live?(ticket_now) &&
      transaction_authority_live?(ticket_now) && context_bound?(context)
  end

  def source_authority_live?(source_now)
    source_owner_matches? && actor.login_allowed? && actor.accessible?(source_now) && contact.accessible?(source_now) &&
      !contact.binding_finalized_at && !contact.binding_released? && pending_candidate?
  end

  def root_authority_live?(ticket_now)
    token.currently_usable?(ticket_now) && token.device_session.usable? &&
      token.device_session.current_refresh_token_id == token.id
  end

  def transaction_authority_live?(ticket_now)
    transaction.status == "pending" && !transaction.consumed_at && transaction.expires_at > ticket_now &&
      transaction.operation == "registration" && transaction.surface == surface &&
      transaction.actor_ref == actor.public_id && transaction.session_ref == token.public_id &&
      ticket_candidate_matches?
  end

  def source_owner_matches?
    case actor
    when Client
      token.user_id == actor.id && contact.user_id == actor.id && token.device_session.user_id == actor.id
    when Visitor
      token.visitor_id == actor.id && contact.visitor_id == actor.id && token.device_session.visitor_id == actor.id
    end
  end

  def pending_candidate?
    case contact
    when ClientEmail then contact.user_email_status_id == ClientEmailStatus::UNVERIFIED
    when ClientTelephone then contact.user_telephone_status_id == ClientTelephoneStatus::UNVERIFIED
    when VisitorEmail then contact.visitor_email_status_id == VisitorEmailStatus::UNVERIFIED
    when VisitorTelephone then contact.visitor_telephone_status_id == VisitorTelephoneStatus::UNVERIFIED
    end
  end

  def ticket_candidate_matches?
    if channel == :email
      transaction.email_candidate_ref == contact.public_id && transaction.normalized_email_digest == destination_digest
    else
      transaction.telephone_candidate_ref == contact.public_id &&
        transaction.normalized_number_digest == destination_digest
    end
  end

  def context_bound?(context)
    context.fetch("version") == 1 && context.fetch("surface") == surface &&
      context.fetch("purpose") == "credential_registration" &&
      context.fetch("flow_ref") == transaction.transaction_id &&
      context.fetch("session_ref") == token.public_id && context.fetch("owner_ref") == actor.public_id &&
      context.fetch("contact_ref") == contact.public_id && context.fetch("destination_digest") == destination_digest &&
      context.fetch("counter") == contact.otp_counter.to_s &&
      context.fetch("browser_digest") == AuthAdmissionBinding.browser_digest(
        surface:, entry_ref: transaction.transaction_id, nonce: browser_nonce,
      )
  end

  def destination_digest
    (channel == :email) ? contact.address_digest : contact.number_digest
  end

  def issuance_matches?(context, otp)
    previous_code = ROTP::HOTP.new(otp.fetch(:otp_private_key)).at(otp.fetch(:otp_counter)).to_s
    previous_digest = CredentialRegistrationOtpCodeDigest.for(context:, channel:, code: previous_code)
    ActiveSupport::SecurityUtils.secure_compare(context.fetch("code_digest"), previous_digest)
  end

  def replace_issuance!(context, counter, deadline, now)
    key = ROTP::Base32.random_base32
    code = ROTP::HOTP.new(key).at(counter).to_s
    updated = context.merge("counter" => counter.to_s, "issued_at" => now.utc.iso8601(6))
    updated["code_digest"] = CredentialRegistrationOtpCodeDigest.for(context: updated, channel:, code:)
    # Integer conversion would shorten a subsecond original deadline; the existing Source API accepts epoch rationals.
    contact.store_otp(key, counter, deadline.to_r, now:)
    contact.update!(credential_registration_otp_context: updated)
    Issuance.new(code: code.freeze, counter: counter.to_s.freeze, transaction:)
  end
end
