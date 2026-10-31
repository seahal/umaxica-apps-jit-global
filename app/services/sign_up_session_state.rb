# typed: false
# frozen_string_literal: true

# Central authority for every session key that belongs to the sign-up flow.
#
# Historically each surface introduced its own key names, so this class owns the
# surface-specific mapping and provides:
#
#   - typed accessors (cycle_payload, sequence_id, telephone_otp, ...)
#   - clear_all! for cancel / completion paths
#   - clear_email_flow! for narrower OTP-restart paths
#
# Callers should prefer this class over reaching into `session[:literal_key]`
# so that adding a new key in one place (the KEY_GROUPS table) propagates
# everywhere a "wipe sign-up state" operation runs.
class SignUpSessionState
  KEY_GROUPS = {
    app: {
      cycle_locator: :app_sign_up_flow_locator,
      sequence_id: :auth_app_up_sequence_id,
      telephone_otp: :user_telephone_registration,
      existing_email: :sign_up_existing_email_id,
      existing_email_skip_otp: :sign_up_existing_email_skip_otp,
    }.freeze,
  }.freeze

  SUPPORTED_SURFACES = KEY_GROUPS.keys.freeze

  def self.for(session, surface:)
    new(session, surface: surface.to_sym)
  end

  def initialize(session, surface:)
    @session = session
    @surface = surface.to_sym
    @keys =
      KEY_GROUPS.fetch(@surface) do
        raise ArgumentError, "unsupported sign-up session surface: #{surface.inspect}"
      end
  end

  def cycle_payload
    @session[@keys.fetch(:cycle_locator)]
  end

  def cycle_payload=(value)
    if value.nil?
      @session.delete(@keys.fetch(:cycle_locator))
    else
      @session[@keys.fetch(:cycle_locator)] = value
    end
  end

  def sequence_id
    @session[@keys.fetch(:sequence_id)]
  end

  def sequence_id=(value)
    if value.nil?
      @session.delete(@keys.fetch(:sequence_id))
    else
      @session[@keys.fetch(:sequence_id)] = value
    end
  end

  def telephone_otp
    @session[@keys.fetch(:telephone_otp)] || {}
  end

  def telephone_otp=(value)
    if value.nil?
      @session.delete(@keys.fetch(:telephone_otp))
    else
      @session[@keys.fetch(:telephone_otp)] = value
    end
  end

  def existing_email
    @session[@keys.fetch(:existing_email)]
  end

  def existing_email=(value)
    if value.nil?
      @session.delete(@keys.fetch(:existing_email))
    else
      @session[@keys.fetch(:existing_email)] = value
    end
  end

  def existing_email_skip_otp?
    @session[@keys.fetch(:existing_email_skip_otp)] == true
  end

  def existing_email_skip_otp=(value)
    if value.nil? || value == false
      @session.delete(@keys.fetch(:existing_email_skip_otp))
    else
      @session[@keys.fetch(:existing_email_skip_otp)] = true
    end
  end

  def clear_email_flow!
    @session.delete(@keys.fetch(:existing_email))
    @session.delete(@keys.fetch(:existing_email_skip_otp))
  end

  def clear_telephone_flow!
    @session.delete(@keys.fetch(:telephone_otp))
  end

  def clear_all!
    @keys.each_value { |k| @session.delete(k) }
  end
end
