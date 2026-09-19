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
  EXISTING_EMAIL_SESSION_KEY = :sign_up_existing_email_id
  EXISTING_EMAIL_SKIP_OTP_SESSION_KEY = :sign_up_existing_email_skip_otp
  DUMMY_EXISTING_EMAIL_SESSION_KEY = :sign_up_dummy_existing_email

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
    session.delete(EXISTING_EMAIL_SESSION_KEY)
    session.delete(EXISTING_EMAIL_SKIP_OTP_SESSION_KEY)
    session.delete(DUMMY_EXISTING_EMAIL_SESSION_KEY)
  end

  def redirect_flow_violation
    flash[:alert] = t("sign.app.registration.email.flow.invalid")
    redirect_to(new_sign_app_sign_up_email_path)
  end

  def initiate_email_verification!(
    email_address,
    confirm_policy: "1",
    allow_existing: false,
    email_preferences: {}
  )
    ensure_signup_reference_defaults!
    return false unless ensure_turnstile!(email_address, confirm_policy)

    build_user_email(email_address, confirm_policy, email_preferences)
    @user_email.user_email_status_id = pending_email_status_id

    @user_email.validate

    return false if @user_email.address_digest.blank?

    create_and_send_verified_email!(allow_existing)
  rescue ActiveRecord::RecordInvalid => e
    @user_email = e.record if e.record.is_a?(ClientEmail)
    false
  end

  def create_and_send_verified_email!(allow_existing)
    result =
      SignUpEmailPendingGuard.with_lock(
        address_digest: @user_email.address_digest,
        model_class: ClientEmail,
      ) do
        process_email_registration_under_lock(allow_existing)
      end

    return :cooldown if result[:cooldown]
    return true if result[:status] == :dummy_existing
    return result[:status] if result[:status] == false || result[:status] == :cooldown
    return false unless result[:status] == :ok

    send_verification_email(result[:otp_number])
    true
  end

  def process_email_registration_under_lock(allow_existing)
    existing_email =
      allow_existing ?
               ClientEmail.find_by(address_digest: @user_email.address_digest) : nil
    uniqueness_only = email_uniqueness_only_error?(@user_email)
    has_errors = @user_email.errors.details.except(:user, :user_id).any?

    if allow_existing && existing_email && !pending_email_status?(existing_email) &&
        (uniqueness_only || !has_errors)
      cleanup_pending_signup!
      session[DUMMY_EXISTING_EMAIL_SESSION_KEY] = dummy_existing_email_session_payload
      @user_email.errors.clear
      return { status: :dummy_existing }
    end

    if has_errors
      return { status: false } unless allow_existing && uniqueness_only &&
        pending_email_status?(existing_email)
    end

    if pending_email_status?(existing_email) &&
        existing_email.reregistration_window_active?
      return { status: :cooldown }
    end

    if pending_email_status?(existing_email)
      locked = ClientEmail.lock.find_by(id: existing_email.id)
      if locked&.reregistration_window_active?
        return { status: nil, cooldown: true }
      end
    end

    cleanup_pending_signup!
    remove_existing_unverified_emails!
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
    turnstile_result = cloudflare_turnstile_validation
    return true if turnstile_result["success"]

    @user_email = ClientEmail.new(raw_address: email_address, confirm_policy: confirm_policy)
    @user_email.errors.add(:base, t("sign.app.registration.email.create.turnstile_validation_failed"))
    false
  end

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

  def remove_existing_unverified_emails!
    return if @user_email.address_digest.blank?

    existing_emails = ClientEmail.where(
      address_digest: @user_email.address_digest,
      user_email_status_id: pending_email_status_ids,
    ).to_a

    pending_user_ids = existing_emails.filter_map(&:user_id)
    Client.where(id: pending_user_ids).find_each(&:destroy!) if pending_user_ids.any?

    existing_emails.each do |email|
      email.destroy! if email.user_id.blank?
    end
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

  def dummy_existing_email_session_payload
    {
      "existing" => true,
      "dummy" => true,
      "expires_at" => CommonOtp::OTP_EXPIRATION_MINUTES.minutes.from_now.to_i,
    }
  end

  def email_uniqueness_only_error?(user_email)
    # ignore :user and :user_id error
    errors_to_check = user_email.errors.details.except(:user, :user_id)
    return false if errors_to_check.empty?

    # Fields that can have uniqueness errors
    uniqueness_fields = %i(address raw_address address_digest)

    # Check if all errors are :taken errors on the uniqueness fields
    errors_to_check.each do |field, errors|
      return false unless uniqueness_fields.include?(field)
      return false unless errors.all? { |error| error[:error] == :taken }
    end

    # Ensure at least one uniqueness error is present
    user_email.errors.details.any?
  end
end
