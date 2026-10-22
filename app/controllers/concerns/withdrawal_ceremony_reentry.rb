# typed: false
# frozen_string_literal: true

module WithdrawalCeremonyReentry
  extend ActiveSupport::Concern
  include EmailOtpResponseTiming
  include EmailValidation
  include WithdrawalCeremonyAuthentication

  REENTRY_SESSION_KEY = :withdrawal_ceremony_reentry
  GENERIC_MESSAGE = I18n.t("withdrawal_ceremony_reentry.generic_message").freeze

  # FIXME: Violates Umaxica/NoConcernInclusionHooks; move the declarations in this block into each class that includes this concern.
  included do
    helper_method :withdrawal_reentry_generic_message
  end

  public

  def new
    @email_record = identity_email_model.new
    @reentry_state = withdrawal_reentry_state
    render_withdrawal_reentry_new
  end

  def create
    return verify_withdrawal_reentry_otp if params[:pass_code].present?

    start_withdrawal_reentry_otp
  end

  private

  def start_withdrawal_reentry_otp
    started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    normalized_address = validate_and_normalize_email(withdrawal_reentry_address)
    email = normalized_address.present? ? find_email_with_timing_protection(normalized_address) : nil
    subject = withdrawal_subject_from_email(email)
    cancel_previous_withdrawal_reentry_otp

    if withdrawal_reentry_subject_eligible?(subject) && !email.locked? && !otp_request_rate_limited?(email)
      browser_ref = SecureRandom.uuid
      transaction = EmailReentryOtpIssuer.call(email: email, operation: "withdrawal", session_ref: browser_ref)
    end

    if transaction
      session[REENTRY_SESSION_KEY] = {
        "email_public_id" => email.public_id,
        "otp_transaction_ref" => transaction.transaction_id,
        "session_ref" => browser_ref,
        "dummy" => false,
        "expires_at" => transaction.otp_expires_at.to_i,
        "padding" => "",
      }
    else
      perform_dummy_otp_generation
      session[REENTRY_SESSION_KEY] = {
        "email_public_id" => PublicId.generate,
        "otp_transaction_ref" => PublicId.generate,
        "session_ref" => SecureRandom.uuid,
        "dummy" => true,
        "expires_at" => EmailCeremonyOtp::OTP_TTL.from_now.to_i,
        "padding" => " ",
      }
    end

    @generic_message = withdrawal_reentry_generic_message
    @reentry_state = withdrawal_reentry_state
    @email_record = identity_email_model.new(address: withdrawal_reentry_address)
    render_withdrawal_reentry_new(status: :ok)
  ensure
    ensure_min_elapsed(started_at, EmailOtpPolicy::EMAIL_AUTH_RESPONSE_MINIMUM_SECONDS)
  end

  # The re-entry screen, as its surface renders it. `render :new` resolves the including
  # controller's own template; a surface whose page is an Inertia component overrides this one
  # method, so the flow control, the statuses and the timing guards stay identical everywhere.
  def render_withdrawal_reentry_new(status: :ok)
    render :new, status: status
  end

  def verify_withdrawal_reentry_otp
    start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    state = withdrawal_reentry_state
    if state.blank? || state["expires_at"].to_i <= Time.current.to_i
      return render_withdrawal_reentry_invalid_code(start_time)
    end
    return render_withdrawal_reentry_invalid_code(start_time) if state["dummy"]

    email = identity_email_model.find_by(public_id: state["email_public_id"].to_s)
    subject = withdrawal_subject_from_email(email)
    unless email && withdrawal_reentry_subject_eligible?(subject)
      return render_withdrawal_reentry_invalid_code(start_time)
    end

    verified = EmailReentryOtpVerificationCommitter.call(
      email: email, code: params[:pass_code], operation: "withdrawal",
      transaction_ref: state["otp_transaction_ref"], session_ref: state["session_ref"],
    )
    unless verified
      return render_withdrawal_reentry_invalid_code(start_time)
    end

    session.delete(REENTRY_SESSION_KEY)
    ensure_min_elapsed(start_time, EmailOtpPolicy::EMAIL_AUTH_RESPONSE_MINIMUM_SECONDS)
    issue_withdrawal_ceremony!(subject: subject, purpose: "status")
    safe_redirect_to(withdrawal_edit_path, fallback: withdrawal_new_path, status: :see_other)
  end

  def render_withdrawal_reentry_invalid_code(start_time)
    verify_dummy_otp(params[:pass_code].to_s)
    ensure_min_elapsed(start_time, EmailOtpPolicy::EMAIL_AUTH_RESPONSE_MINIMUM_SECONDS)
    @generic_message = withdrawal_reentry_generic_message
    @reentry_state = withdrawal_reentry_state
    @email_record = identity_email_model.new(address: withdrawal_reentry_address)
    render_withdrawal_reentry_new(status: :unprocessable_content)
  end

  def withdrawal_reentry_state
    data = session[REENTRY_SESSION_KEY]
    return nil unless data.is_a?(Hash)

    if data["expires_at"].to_i <= Time.current.to_i
      session.delete(REENTRY_SESSION_KEY)
      return nil
    end

    data
  end

  def withdrawal_reentry_address
    params.dig(:withdrawal_reentry, :address).to_s
  end

  def withdrawal_reentry_generic_message
    GENERIC_MESSAGE
  end

  def otp_request_rate_limited?(email)
    email.otp_cooldown_active?
  end

  def cancel_previous_withdrawal_reentry_otp
    state = session[REENTRY_SESSION_KEY]
    return unless state.is_a?(Hash) && !state["dummy"]

    transaction = withdrawal_email_ceremony_model.find_by(transaction_id: state["otp_transaction_ref"])
    return unless transaction && transaction.session_ref == state["session_ref"] &&
      transaction.email_candidate_ref == state["email_public_id"] && transaction.operation == "withdrawal"

    transaction.cancel_email_otp!
  end

  def withdrawal_reentry_subject_eligible?(subject)
    return false if subject.blank?
    return false unless subject.respond_to?(:withdrawal_in_progress?)
    return false if subject.active?

    subject.withdrawal_in_progress? || subject.terminated?
  end
end
