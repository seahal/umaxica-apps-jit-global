# frozen_string_literal: true

class ContactRegistrationOtpVerificationCommitter
  class << self
    public

    def call!(**arguments)
      new(**arguments).call!
    end
  end

  public

  def initialize(actor:, token:, contact:, transaction:, channel:, browser_nonce:, code:)
    @actor = actor
    @token = token
    @contact = contact
    @transaction = transaction
    @channel = channel
    @browser_nonce = browser_nonce
    @code = code
    @surface =
      case [actor, token, contact, transaction, channel]
      in [Client, ClientToken, ClientEmail, ClientEmailCeremonyTransaction, :email] |
         [Client, ClientToken, ClientTelephone, ClientTelephoneCeremonyTransaction, :telephone] then "app"
      in [Visitor, VisitorToken, VisitorEmail, VisitorEmailCeremonyTransaction, :email] |
         [Visitor, VisitorToken, VisitorTelephone, VisitorTelephoneCeremonyTransaction, :telephone] then "com"
      else raise ArgumentError, "unsupported Contact verification binding"
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
                contact.with_lock { verify_under_locks! }
              end
            end
          end
        end
      end
    end
  end

  private

  attr_reader :actor, :token, :contact, :transaction, :channel, :browser_nonce, :code, :surface

  def verify_under_locks!
    ticket_now = transaction.class.database_now
    source_now = contact.class.database_now
    context = contact.credential_registration_otp_context
    return :unavailable unless context && authority_matches?(context, ticket_now, source_now)
    return :locked if contact.locked?(now: source_now)
    return :invalid_code unless code.is_a?(String) && code.match?(/\A[0-9]{6}\z/)

    if context.fetch("verified_at")
      return :unavailable if Time.iso8601(context.fetch("result_expires_at")) <= source_now

      return verify_code!(context, source_now, retained: true)
    end
    return :unavailable if Time.iso8601(context.fetch("expires_at")) <= source_now
    return :unavailable if contact.binding_finalized_at || !pending_candidate? ||
      context.fetch("counter") != contact.otp_counter.to_s

    verify_code!(context, source_now, retained: false)
  end

  def authority_matches?(context, ticket_now, source_now)
    source_authority_live?(source_now) && root_authority_live?(ticket_now) &&
      transaction_authority_live?(ticket_now) && context_bound?(context)
  end

  def source_authority_live?(now)
    source_owner_matches? && actor.login_allowed? && actor.accessible?(now) &&
      contact.accessible?(now) && !contact.binding_released?
  end

  def root_authority_live?(now)
    token.currently_usable?(now) && token.device_session.usable? &&
      token.device_session.current_refresh_token_id == token.id
  end

  def transaction_authority_live?(now)
    transaction.expires_at > now && !transaction.consumed? &&
      transaction.operation == "registration" && transaction.surface == surface &&
      transaction.actor_ref == actor.public_id && transaction.session_ref == token.public_id &&
      ticket_candidate_matches?
  end

  def context_bound?(context)
    context.fetch("version") == 1 && context.fetch("surface") == surface &&
      context.fetch("purpose") == "credential_registration" &&
      context.fetch("flow_ref") == transaction.transaction_id &&
      context.fetch("session_ref") == token.public_id && context.fetch("owner_ref") == actor.public_id &&
      context.fetch("contact_ref") == contact.public_id && context.fetch("destination_digest") == destination_digest &&
      context.fetch("browser_digest") == AuthAdmissionBinding.browser_digest(
        surface: surface, entry_ref: transaction.transaction_id, nonce: browser_nonce,
      )
  end

  def source_owner_matches?
    case actor
    when Client then token.user_id == actor.id && contact.user_id == actor.id
    when Visitor then token.visitor_id == actor.id && contact.visitor_id == actor.id
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

  def pending_candidate?
    case contact
    when ClientEmail then contact.user_email_status_id == ClientEmailStatus::UNVERIFIED
    when ClientTelephone then contact.user_telephone_status_id == ClientTelephoneStatus::UNVERIFIED
    when VisitorEmail then contact.visitor_email_status_id == VisitorEmailStatus::UNVERIFIED
    when VisitorTelephone then contact.visitor_telephone_status_id == VisitorTelephoneStatus::UNVERIFIED
    end
  end

  def destination_digest
    (channel == :email) ? contact.address_digest : contact.number_digest
  end

  def verify_code!(context, now, retained:)
    candidate_digest = CredentialRegistrationOtpCodeDigest.for(context: context, channel: channel, code: code)
    valid = ActiveSupport::SecurityUtils.secure_compare(context.fetch("code_digest"), candidate_digest)
    unless retained
      otp = contact.get_otp
      return :unavailable unless otp

      expected = ROTP::HOTP.new(otp.fetch(:otp_private_key)).at(otp.fetch(:otp_counter)).to_s
      valid &&= ActiveSupport::SecurityUtils.secure_compare(expected, code)
    end
    verifier_budget =
      case channel
      when :email then EmailOtpVerificationFailureBudget.new
      when :telephone then TelephoneOtpVerificationFailureBudget.new
      else raise ArgumentError, "unsupported OTP channel"
      end
    budget = verifier_budget.verify!(
      surface: surface.to_sym, purpose: :credential_registration, channel: channel,
      destination_digest: destination_digest, valid: valid,
    )
    contact.increment_attempts! unless valid
    return :locked if budget == :locked || contact.locked?(now: now)
    return :invalid_code unless valid
    return :verified if retained

    contact.clear_otp(reset_attempts: true)
    contact.update!(
      credential_registration_otp_context: context.merge(
        "verified_at" => now.utc.iso8601(6),
        "result_expires_at" => [now + 60.seconds, transaction.expires_at].min.utc.iso8601(6),
      ),
    )
    :verified
  end
end
