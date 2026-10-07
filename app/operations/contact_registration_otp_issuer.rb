# frozen_string_literal: true

class ContactRegistrationOtpIssuer
  class << self
    public

    def call!(**arguments)
      new(**arguments).call!
    end
  end

  public

  def initialize(actor:, token:, contact:, channel:, browser_nonce:, code:)
    @actor = actor
    @token = token
    @contact = contact
    @channel = channel
    @browser_nonce = browser_nonce
    @code = code
    @surface, @flow_model =
      case [actor, token, contact, channel]
      in [Client, ClientToken, ClientEmail, :email] then ["app", ClientEmailCeremonyTransaction]
      in [Client, ClientToken, ClientTelephone, :telephone] then ["app", ClientTelephoneCeremonyTransaction]
      in [Visitor, VisitorToken, VisitorEmail, :email] then ["com", VisitorEmailCeremonyTransaction]
      in [Visitor, VisitorToken, VisitorTelephone, :telephone] then ["com", VisitorTelephoneCeremonyTransaction]
      else raise ArgumentError, "unsupported Contact registration binding"
      end
    return if browser_nonce.is_a?(String) && browser_nonce.match?(/\A[A-Za-z0-9_-]{43}\z/)

    raise ArgumentError, "registration browser binding is required"

  end

  def call!
    actor.class.connection_class_for_self.connected_to(role: :writing) do
      actor.with_lock do
        flow_model.connection_owner.connected_to(role: :writing) do
          token.device_session.with_lock do
            token.with_lock do
              contact.with_lock { issue_under_locks! }
            end
          end
        end
      end
    end
  end

  private

  attr_reader :actor, :token, :contact, :channel, :browser_nonce, :code, :surface, :flow_model

  def issue_under_locks!
    ticket_now = flow_model.database_now
    source_now = contact.class.database_now
    validate_live_binding!(ticket_now, source_now)
    otp = contact.get_otp
    raise ArgumentError, "registration OTP is unavailable" unless otp

    expected = ROTP::HOTP.new(otp.fetch(:otp_private_key)).at(otp.fetch(:otp_counter)).to_s
    unless code.is_a?(String) && code.bytesize == expected.bytesize &&
        ActiveSupport::SecurityUtils.secure_compare(code, expected)
      raise ArgumentError, "registration issuance code does not match candidate"
    end

    transaction = create_transaction!(ticket_now)
    contact.update!(credential_registration_otp_context: challenge_context(transaction, source_now))
    transaction
  end

  def validate_live_binding!(ticket_now, source_now)
    owner_matches =
      case actor
      when Client then token.user_id == actor.id && contact.user_id == actor.id
      when Visitor then token.visitor_id == actor.id && contact.visitor_id == actor.id
      end
    unless owner_matches && actor.login_allowed? && actor.accessible?(source_now) && contact.accessible?(source_now) &&
        token.currently_usable?(ticket_now) && token.device_session.usable? &&
        token.device_session.current_refresh_token_id == token.id
      raise ArgumentError, "registration owner or root is unavailable"
    end
    if contact.binding_finalized_at || contact.binding_released? || contact.locked? ||
        contact.credential_registration_otp_context
      raise ArgumentError, "registration candidate is unavailable"
    end
  end

  def create_transaction!(now)
    candidate_attributes =
      if channel == :email
        { email_candidate_ref: contact.public_id, normalized_email_digest: contact.address_digest }
      else
        { telephone_candidate_ref: contact.public_id, normalized_number_digest: contact.number_digest }
      end
    flow_model.create_transaction!(
      surface: surface, actor_ref: actor.public_id, session_ref: token.public_id, operation: "registration",
      transaction_id: SecureRandom.uuid, grant_jti: SecureRandom.uuid, now: now,
      expires_at: now + EmailCeremonyTransactionable::DEFAULT_TTL, **candidate_attributes,
    )
  end

  def challenge_context(transaction, now)
    context = {
      "version" => 1,
      "surface" => surface,
      "purpose" => "credential_registration",
      "flow_ref" => transaction.transaction_id,
      "browser_digest" => AuthAdmissionBinding.browser_digest(
        surface: surface, entry_ref: transaction.transaction_id, nonce: browser_nonce,
      ),
      "session_ref" => token.public_id,
      "owner_ref" => actor.public_id,
      "contact_ref" => contact.public_id,
      "destination_digest" => (channel == :email) ? contact.address_digest : contact.number_digest,
      "counter" => contact.otp_counter.to_s,
      "issued_at" => now.utc.iso8601(6),
      "expires_at" => [contact.otp_expires_at, transaction.expires_at].min.utc.iso8601(6),
      "verified_at" => nil,
      "result_expires_at" => nil,
    }
    context["code_digest"] = CredentialRegistrationOtpCodeDigest.for(context: context, channel: channel, code: code)
    context
  end
end
