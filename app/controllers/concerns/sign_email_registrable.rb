# typed: false
# frozen_string_literal: true

# Guest signup callers provide process_email_registration_under_lock and send_verification_email;
# authenticated settings callers own initiation rather than inheriting guest proof issuance.
module SignEmailRegistrable
  extend ActiveSupport::Concern

  STATE_INIT = "init"
  STATE_EMAIL_CREATED = "email_created"
  STATE_EMAIL_VERIFIED = "email_verified"
  VALID_STATES = [STATE_INIT, STATE_EMAIL_CREATED, STATE_EMAIL_VERIFIED].freeze

  FLOW_REQUIREMENTS = {
    new: STATE_INIT,
    create: STATE_INIT,
    edit: STATE_EMAIL_CREATED,
    update: STATE_EMAIL_CREATED,
    show: STATE_EMAIL_VERIFIED,
    destroy: STATE_EMAIL_VERIFIED,
  }.freeze

  FLOW_PROGRESSIONS = {
    create: STATE_EMAIL_CREATED,
    update: STATE_EMAIL_VERIFIED,
    destroy: STATE_INIT,
  }.freeze

  SESSION_KEY = :sign_up_email_flow_state

  private

  def enforce_email_flow!
    required_state = FLOW_REQUIREMENTS[action_name.to_sym]
    return unless required_state

    current_state = email_flow_state
    if action_name.to_sym.in?([:new, :create]) && current_state != STATE_INIT
      reset_email_flow!
      return
    end

    return if current_state == required_state

    redirect_flow_violation
  end

  def email_flow_state
    current_state = session[SESSION_KEY]
    current_state = current_state.to_s if current_state.present?
    current_state = STATE_INIT unless VALID_STATES.include?(current_state)
    session[SESSION_KEY] = current_state
  end

  def progress_email_flow!(action)
    next_state = FLOW_PROGRESSIONS[action.to_sym]
    session[SESSION_KEY] = next_state if next_state
  end

  def reset_email_flow!
    session[SESSION_KEY] = STATE_INIT
  end

  def redirect_flow_violation
    flash[:alert] = t("sign.app.registration.email.flow.invalid")
    redirect_to(new_sign_app_sign_up_email_path)
  end

  def initiate_email_verification!(
    email_address,
    confirm_policy: "1",
    email_preferences: {}
  )
    ensure_signup_reference_defaults!
    return false unless ensure_turnstile!(email_address, confirm_policy)

    build_user_email(email_address, confirm_policy, email_preferences)
    @user_email.user_email_status_id = pending_email_status_id

    @user_email.validate

    return false if @user_email.address_digest.blank?

    create_and_send_verified_email!
  rescue ActiveRecord::RecordInvalid => e
    @user_email = e.record if e.record.is_a?(ClientEmail)
    false
  end

  def create_and_send_verified_email!
    result =
      SignUpEmailPendingGuard.with_lock(
        address_digest: @user_email.address_digest,
        model_class: ClientEmail,
      ) do
        process_email_registration_under_lock
      end

    return :cooldown if result[:cooldown]
    return result[:status] if [false, :cooldown].include?(result[:status])
    return false unless result[:status] == :ok

    send_verification_email(result[:otp_number])
    true
  end

  def ensure_turnstile!(email_address, confirm_policy)
    turnstile_result = email_registration_turnstile_validation
    return true if turnstile_result["success"]

    @user_email = ClientEmail.new(raw_address: email_address, confirm_policy: confirm_policy)
    @user_email.errors.add(:base, t("sign.app.registration.email.create.turnstile_validation_failed"))
    false
  end

  # Sign-up draws the visible widget; a host whose form draws the stealth widget overrides this so
  # the token is verified against the secret that matches the site key it was issued for.
  def email_registration_turnstile_validation = cloudflare_turnstile_validation

  def build_user_email(email_address, confirm_policy, email_preferences = {})
    email_preferences = email_preferences.to_unsafe_h if email_preferences.respond_to?(:to_unsafe_h)
    @user_email = ClientEmail.new(
      { raw_address: email_address, confirm_policy: confirm_policy }.merge(email_preferences),
    )
  end

  def pending_email_status_id
    ClientEmailStatus::UNVERIFIED_WITH_SIGN_UP
  end

  def verified_email_status_id
    ClientEmailStatus::VERIFIED_WITH_SIGN_UP
  end

  def pending_email_status_ids
    [pending_email_status_id]
  end

  def pending_email_status?(user_email)
    user_email.present? && pending_email_status_ids.include?(user_email.user_email_status_id)
  end

  def ensure_signup_reference_defaults!
    ClientStatus.ensure_defaults!
    ClientVisibility.ensure_defaults!
    ClientMfaStatus.ensure_defaults!
    ClientEmailStatus.ensure_defaults!
  end
end
