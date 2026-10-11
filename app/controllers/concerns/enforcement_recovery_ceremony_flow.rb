# typed: false
# frozen_string_literal: true

# Email OTP re-entry for a verification-required Enforcement Case. It never
# calls normal authentication or issues tokens; the only durable browser state
# is the recovery ceremony cookie created after a successful OTP check.
module EnforcementRecoveryCeremonyFlow
  extend ActiveSupport::Concern

  include CommonOtp
  include EmailValidation

  REENTRY_SESSION_KEY = :enforcement_recovery_reentry

  def new
    @email_record = identity_email_model.new
    @reentry_state = recovery_reentry_state
    render_recovery_reentry_new
  end

  def create
    return verify_recovery_otp if params[:pass_code].present?

    start_recovery_otp
  end

  private

  def start_recovery_otp
    normalized_address = validate_and_normalize_email(recovery_reentry_address)
    email = normalized_address.present? ? find_email_with_timing_protection(normalized_address) : nil
    subject = recovery_subject_from_email(email)

    if recovery_subject_eligible?(subject) && recovery_email_verified?(email) && !email.locked?
      && !otp_request_rate_limited?(email)
      otp_code = generate_otp_for(email)
      OtpAdapter.for(surface: recovery_surface, channel: :email).deliver(record: email, otp_code: otp_code)
      session[REENTRY_SESSION_KEY] = { "email_public_id" => email.public_id,
                                       "dummy" => false,
                                       "expires_at" => CommonOtp::OTP_EXPIRATION_MINUTES.minutes.from_now.to_i, }
    else
      perform_dummy_otp_generation
      session[REENTRY_SESSION_KEY] = { "dummy" => true, "expires_at" => CommonOtp::OTP_EXPIRATION_MINUTES.minutes.from_now.to_i }
    end

    @email_record = identity_email_model.new(address: recovery_reentry_address)
    @reentry_state = recovery_reentry_state
    render_recovery_reentry_new(status: :ok)
  end

  # The re-entry screen, as its surface renders it. `render :new` resolves the including
  # controller's own template; a surface whose page is an Inertia component overrides this one
  # method, so the flow control, the statuses and the timing guards stay identical everywhere.
  def render_recovery_reentry_new(status: :ok)
    render :new, status: status
  end

  def verify_recovery_otp
    started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    state = recovery_reentry_state
    return render_invalid_recovery_otp(started_at) if state.blank? || state["dummy"]

    email = identity_email_model.find_by(public_id: state["email_public_id"].to_s)
    subject = recovery_subject_from_email(email)
    return render_invalid_recovery_otp(started_at) \
      unless recovery_subject_eligible?(subject) && recovery_email_verified?(email)

    result = verify_otp_code_and_consume(email, params[:pass_code])
    unless result[:success]
      return render_invalid_recovery_otp(started_at)
    end

    session.delete(REENTRY_SESSION_KEY)
    ensure_min_elapsed(started_at)
    ceremony = recovery_ceremony_class.issue!(subject: subject, request: request)
    write_recovery_ceremony_cookie!(ceremony)
    safe_redirect_to(recovery_status_path, fallback: recovery_entry_path, status: :see_other)
  end

  def render_invalid_recovery_otp(started_at)
    verify_dummy_otp(params[:pass_code].to_s)
    ensure_min_elapsed(started_at)
    @email_record = identity_email_model.new(address: recovery_reentry_address)
    @reentry_state = recovery_reentry_state
    render_recovery_reentry_new(status: :unprocessable_content)
  end

  def recovery_reentry_state
    data = session[REENTRY_SESSION_KEY]
    return nil unless data.is_a?(Hash)
    return session.delete(REENTRY_SESSION_KEY) if data["expires_at"].to_i <= Time.current.to_i

    data
  end

  def recovery_reentry_address = params.dig(:recovery_reentry, :address).to_s

  def recovery_subject_eligible?(subject)
    subject.present? && recovery_case_class.in_force.exists?(
      principal_public_id: subject.public_id,
      kind: "security_lock", visibility: "visible", release_mode: "verification_required",
    )
  end

  def recovery_email_verified?(email)
    email.present? && recovery_verified_email_status_ids.include?(email.public_send(recovery_email_status_column))
  end

  def otp_request_rate_limited?(email) = email.respond_to?(:otp_cooldown_active?) && email.otp_cooldown_active?
end
