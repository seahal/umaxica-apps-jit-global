# frozen_string_literal: true

class ContactRegistrationOtpDeliveryIssuer
  class << self
    public

    def call(**arguments, &)
      new(**arguments).call(&)
    end
  end

  public

  def initialize(transaction:, contact_ref:, counter:, destination:, code: nil, message_body: nil)
    @transaction = transaction
    @contact_ref = contact_ref
    @counter = counter
    @destination = destination
    @code = code
    @message_body = message_body
    @surface, @channel, @owner_model, @token_model, @contact_model =
      case transaction
      when ClientEmailCeremonyTransaction then ["app", :email, Client, ClientToken, ClientEmail]
      when ClientTelephoneCeremonyTransaction then ["app", :telephone, Client, ClientToken, ClientTelephone]
      when VisitorEmailCeremonyTransaction then ["com", :email, Visitor, VisitorToken, VisitorEmail]
      when VisitorTelephoneCeremonyTransaction then ["com", :telephone, Visitor, VisitorToken, VisitorTelephone]
      else raise ArgumentError, "unsupported Contact delivery realm"
      end
    unless contact_ref.is_a?(String) && contact_ref.match?(/\A[A-Za-z0-9_-]{1,21}\z/) &&
        counter.is_a?(String) && counter.match?(/\A(?:0|[1-9][0-9]{0,19})\z/) && counter.to_i < (1 << 64)
      raise ArgumentError, "invalid Contact OTP delivery binding"
    end
  end

  def call
    raise ArgumentError, "transport block required" unless block_given?

    owner = owner_model.find_by(public_id: transaction.actor_ref)
    token = token_model.find_by(public_id: transaction.session_ref)
    contact = contact_model.find_by(public_id: contact_ref)
    return false unless owner && token && contact

    owner_model.connection_class_for_self.connected_to(role: :writing) do
      owner.with_lock do
        transaction.class.connection_owner.connected_to(role: :writing) do
          token.device_session.with_lock do
            token.with_lock do
              transaction.with_lock do
                contact.with_lock do
                  return false unless eligible_source?(owner, token, contact) && eligible_ticket?(owner, token)

                  yield
                  true
                end
              end
            end
          end
        end
      end
    end
  end

  private

  attr_reader :transaction, :contact_ref, :counter, :destination, :code, :message_body,
              :surface, :channel, :owner_model, :token_model, :contact_model

  def eligible_ticket?(owner, token)
    now = transaction.class.database_now
    transaction.surface == surface && transaction.operation == "registration" &&
      transaction.actor_ref == owner.public_id && transaction.session_ref == token.public_id &&
      transaction.expires_at > now && !transaction.consumed? && token.currently_usable?(now) &&
      token.device_session.usable? && token.device_session.current_refresh_token_id == token.id
  end

  def eligible_source?(owner, token, contact)
    now = contact.class.database_now
    return false unless owner.login_allowed? && owner.accessible?(now) && contact.accessible?(now) &&
      source_owner_matches?(owner, token, contact)
    return false if contact.binding_finalized_at || contact.binding_released?

    context = contact.credential_registration_otp_context
    return false unless context && context_matches?(context, owner, token, contact)
    return false if context.fetch("verified_at") || Time.iso8601(context.fetch("expires_at")) <= now

    otp = contact.get_otp
    return false unless otp && otp.fetch(:otp_counter).to_s == counter && pending_candidate?(contact)

    code_matches?(context, otp)
  end

  def source_owner_matches?(owner, token, contact)
    case owner
    when Client then token.user_id == owner.id && contact.user_id == owner.id
    when Visitor then token.visitor_id == owner.id && contact.visitor_id == owner.id
    end
  end

  def context_matches?(context, owner, token, contact)
    digest = (channel == :email) ? contact.address_digest : contact.number_digest
    delivered_digest =
      (channel == :email) ? IdentifierBlindIndex.bidx_for_email(destination, realm: surface) :
                           IdentifierBlindIndex.bidx_for_telephone(destination, realm: surface)
    ticket_matches =
      if channel == :email
        transaction.email_candidate_ref == contact_ref && transaction.normalized_email_digest == digest
      else
        transaction.telephone_candidate_ref == contact_ref && transaction.normalized_number_digest == digest
      end
    ticket_matches && digest == delivered_digest && context.fetch("version") == 1 &&
      context.fetch("surface") == surface && context.fetch("purpose") == "credential_registration" &&
      context.fetch("flow_ref") == transaction.transaction_id && context.fetch("counter") == counter &&
      context.fetch("owner_ref") == owner.public_id && context.fetch("session_ref") == token.public_id &&
      context.fetch("contact_ref") == contact_ref && context.fetch("destination_digest") == digest
  end

  def pending_candidate?(contact)
    case contact
    when ClientEmail then contact.user_email_status_id == ClientEmailStatus::UNVERIFIED
    when ClientTelephone then contact.user_telephone_status_id == ClientTelephoneStatus::UNVERIFIED
    when VisitorEmail then contact.visitor_email_status_id == VisitorEmailStatus::UNVERIFIED
    when VisitorTelephone then contact.visitor_telephone_status_id == VisitorTelephoneStatus::UNVERIFIED
    end
  end

  def code_matches?(context, otp)
    return true if code.nil? && message_body.nil?

    expected = ROTP::HOTP.new(otp.fetch(:otp_private_key)).at(otp.fetch(:otp_counter)).to_s
    unless code.nil?
      return false unless code.is_a?(String) && code.match?(/\A[0-9]{6}\z/) &&
        ActiveSupport::SecurityUtils.secure_compare(expected, code)
    end
    return false if message_body && !message_body_matches?(expected)

    digest = CredentialRegistrationOtpCodeDigest.for(context: context, channel: channel, code: expected)
    ActiveSupport::SecurityUtils.secure_compare(context.fetch("code_digest"), digest)
  end

  def message_body_matches?(expected)
    channel == :telephone && message_body.is_a?(String) &&
      (message_body == "Your verification code: #{expected}" ||
       message_body == I18n.t("sign.telephone_verification.sms_message", code: expected))
  end
end
