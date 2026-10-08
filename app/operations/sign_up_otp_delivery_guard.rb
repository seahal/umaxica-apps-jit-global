# frozen_string_literal: true

class SignUpOtpDeliveryGuard
  class << self
    public

    def call(**arguments, &)
      new(**arguments).call(&)
    end
  end

  public

  def initialize(flow:, channel:, contact_ref:, counter:, destination:, code: nil)
    @flow = flow
    @channel = channel.to_sym
    @contact_ref = contact_ref
    @counter = counter
    @destination = destination
    @code = code
    unless %i(email telephone).include?(@channel) && contact_ref.is_a?(String) && contact_ref.present? &&
        counter.is_a?(String) && counter.match?(/\A(?:0|[1-9][0-9]{0,19})\z/) && counter.to_i < (1 << 64)
      raise ArgumentError, "invalid signup OTP delivery binding"
    end
  end

  def call
    raise ArgumentError, "transport block required" unless block_given?

    flow.with_cycle_lock do
      return false unless active_flow?
      return false unless flow.pending_contact_type == channel.to_s

      owner_model.connection_class_for_self.connected_to(role: :writing) do
        with_eligible_source { yield }
      end
    end
  end

  private

  attr_reader :flow, :channel, :contact_ref, :counter, :destination, :code

  def with_eligible_source
    owner = owner_model.find_by(id: flow.principal_id)
    return false unless owner

    owner.with_lock do
      contact = contact_model.find_by(id: flow.pending_contact_id, public_id: contact_ref)
      return false unless contact

      contact.with_lock do
        return false unless active_flow? && eligible_source?(owner, contact)

        yield
        true
      end
    end
  end

  def active_flow?
    return false if flow.sign_up_terminal?

    now = flow.class.database_now
    if flow.expired?(now)
      SignUpTermination.call(cycle: flow, event: :expire)
      return false
    end

    !flow.lapsed?(now)
  end

  def owner_model
    case flow
    when ClientSignUpFlow then Client
    when VisitorSignUpFlow then Visitor
    else raise ArgumentError, "unsupported signup OTP delivery realm"
    end
  end

  def contact_model
    case [owner_model.name, channel]
    when ["Client", :email] then ClientEmail
    when ["Client", :telephone] then ClientTelephone
    when ["Visitor", :email] then VisitorEmail
    when ["Visitor", :telephone] then VisitorTelephone
    end
  end

  def eligible_source?(owner, contact)
    owner_key = (owner_model == Client) ? :user_id : :visitor_id
    pending_status = (owner_model == Client) ? ClientStatus::UNVERIFIED_WITH_SIGN_UP : VisitorStatus::ACTIVE
    source_now = contact.class.database_now
    return false unless owner.status_id == pending_status && owner.active? && owner.access_enabled? &&
      owner.accessible?(source_now)
    return false unless contact.public_send(owner_key) == owner.id && contact.accessible?(source_now)
    return false if contact.binding_finalized_at || contact.binding_released?

    otp = contact.get_otp
    return false unless otp && otp.fetch(:otp_counter).to_s == counter

    expected_digest = (channel == :email) ? contact.address_digest : contact.number_digest
    delivered_digest =
      if channel == :email
        IdentifierBlindIndex.bidx_for_email(destination, realm: contact.class.identifier_hmac_realm)
      else
        IdentifierBlindIndex.bidx_for_telephone(destination, realm: contact.class.identifier_hmac_realm)
      end
    return false unless delivered_digest == expected_digest

    code_matches?(otp)
  end

  def code_matches?(otp)
    return true if code.nil?

    expected_code = ROTP::HOTP.new(otp.fetch(:otp_private_key)).at(otp.fetch(:otp_counter)).to_s
    code.is_a?(String) && code.bytesize == expected_code.bytesize &&
      ActiveSupport::SecurityUtils.secure_compare(code, expected_code)
  end
end
