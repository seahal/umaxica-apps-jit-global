# typed: false
# frozen_string_literal: true

module SignSettingsTotpRegistration
  extend ActiveSupport::Concern

  private

  def finish_totp_ceremony!(surface:, actor:, session_ref:, private_key:, title:, last_otp_at:, # rubocop:disable Lint/UnusedMethodArgument
                            _operation: "registration")
    create_settings_totp!(
      surface: surface,
      actor: actor,
      private_key: private_key,
      title: title,
      last_otp_at: last_otp_at,
    )
  end

  def create_settings_totp!(surface:, actor:, private_key:, title:, last_otp_at:)
    raise IdentityTotpCeremonyContract::Error, "surface is invalid" unless surface.to_s == "app"

    totp = ClientTotpCredential.create_for_user!(
      user: actor,
      private_key: private_key,
      last_otp_at: last_otp_at,
      title: title,
      user_totp_credential_status_id: ClientTotpCredentialStatus::ACTIVE,
    )
    IdentityAudit.record!(
      actor: actor,
      event_id: ClientChronicleEvent::TOTP_ENABLED,
      action: "totp.enable",
      subject: totp,
      ip_address: request.remote_ip,
      user_agent: request.user_agent,
    )
    Struct.new(:totp).new(totp)
  end

  def reset_totp_ceremony_session!
    session.delete(totp_ceremony_session_key)
  end

  # An enrolment is the only holder of a not-yet-confirmed secret. It is created by an explicit
  # POST, identified by its own id so a page from an earlier enrolment cannot confirm the current
  # one, and bounded by a lifetime. Nothing else reads or reuses a secret from the session.
  def start_totp_enrollment!
    end_totp_enrollment!
    session[totp_enrollment_session_key] = {
      "id" => SecureRandom.urlsafe_base64(16),
      "private_key" => ROTP::Base32.random_base32,
      "expires_at" => totp_enrollment_ttl.from_now.to_i,
    }
  end

  def active_totp_enrollment
    data = session[totp_enrollment_session_key]
    return nil unless data.is_a?(Hash)

    data = data.stringify_keys
    return nil if data["id"].blank? || data["private_key"].blank?
    return nil if data["expires_at"].to_i <= Time.current.to_i

    data
  end

  def totp_enrollment_matches?(enrollment, submitted_id)
    enrollment.present? && submitted_id.is_a?(String) &&
      ActiveSupport::SecurityUtils.secure_compare(enrollment.fetch("id"), submitted_id)
  end

  # Ends the enrolment and every piece of temporary state it owned. `:private_key` is the key the
  # enrolment used before it had its own lifecycle; it is removed so no earlier secret survives.
  def end_totp_enrollment!
    session.delete(totp_enrollment_session_key)
    session.delete(:private_key)
    reset_totp_ceremony_session!
  end

  def totp_enrollment_session_key
    :totp_enrollment
  end

  def totp_enrollment_ttl
    10.minutes
  end

  def totp_ceremony_session_key
    :totp_ceremony
  end
end
