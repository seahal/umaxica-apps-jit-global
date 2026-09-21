# typed: false
# frozen_string_literal: true

module SignSettingsTotpRegistration
  extend ActiveSupport::Concern

  private

  def start_totp_ceremony!(_surface:, _actor:, _session_ref:, _operation: "registration")
    nil
  end

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

  def totp_ceremony_session_key
    :totp_ceremony
  end
end
