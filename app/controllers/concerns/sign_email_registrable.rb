# typed: false
# frozen_string_literal: true

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
    return result[:status] if result[:status] == false || result[:status] == :cooldown
    return false unless result[:status] == :ok

    send_verification_email(result[:otp_number])
    true
  end

  def process_email_registration_under_lock
    has_errors = @user_email.errors.details.except(:user, :user_id).any?

    cleanup_pending_signup!
    return { status: false } if has_errors

    create_pending_user!

    otp_number = generate_otp_attributes(@user_email)
    @user_email.otp_last_sent_at = Time.current
    @user_email.save!
    { status: :ok, otp_number: otp_number }
  end

  def complete_email_verification!(id, submitted_code, token = nil, commit_verified_status: true)
    @user_email = ClientEmail.find_by(public_id: id)

    # Session validation should be done in controller
    # This method assumes valid session

    # Verify token if provided (strict verification)
    if token.present?
      unless @user_email.verify_verification_token(token)
        @user_email.errors.add(:base, t("sign.app.registration.email.update.invalid_token"))
        return false
      end
    end

    result = nil
    begin
      @user_email.transaction do
        result = verify_otp_code_and_consume(@user_email, submitted_code)
        if result[:success]
          @user_email.user_email_status_id = verified_email_status_id if commit_verified_status

          yield(@user_email) if block_given?
          @user_email.save! if @user_email.changed?
        end
      end
    rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotSaved => e
      # Transaction rolled back
      @user_email.errors.add(:base, e.message) if @user_email.errors.empty?
      return false
    end

    unless result[:success]
      if @user_email.locked?
        @user_email.destroy!
        @user_email.errors.add(:base, :locked)
        return :locked
      end

      @user_email.errors.add(:pass_code, t("sign.app.registration.email.update.invalid_code"))
      return false
    end

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

  # Hook for subclasses to clean up a pending actor before starting a new registration attempt.
  # The base implementation is a no-op; controllers that track the pending actor through a
  # sign-up flow ticket should override this to use the ticket's principal_id instead.
  def cleanup_pending_signup!
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

  def create_pending_user!
    @pending_user = Client.create!(status_id: ClientStatus::UNVERIFIED_WITH_SIGN_UP)
    @user_email.user = @pending_user
    # Pending actor is tracked through the sign-up flow ticket (principal_id) after
    # bind_sign_up_flow_to_email! runs; no session key is needed here.
  end

  def ensure_signup_reference_defaults!
    ClientStatus.ensure_defaults!
    ClientVisibility.ensure_defaults!
    ClientMfaLevel.ensure_defaults!
    ClientMfaStatus.ensure_defaults!
    ClientEmailStatus.ensure_defaults!
  end

  def send_verification_email(otp_number)
    token = @user_email.generate_verification_token

    OtpAdapter.for(surface: :app, channel: :email).deliver(
      record: @user_email,
      otp_code: otp_number,
      verification_token: token,
      public_id: @user_email.public_id,
      purpose: email_otp_purpose,
    )
  end

  def email_otp_purpose
    nil
  end
end
