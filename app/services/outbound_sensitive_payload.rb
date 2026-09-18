# typed: false
# frozen_string_literal: true

module OutboundSensitivePayload
  SMS_BODY_PURPOSE = "outbound.sms.body"
  EMAIL_OTP_PURPOSE = "outbound.email.otp"
  EMAIL_VERIFICATION_TOKEN_PURPOSE = "outbound.email.verification_token"
  SMS_DELIVERY_PURPOSE = "outbound.sms.delivery.v1"
  OIDC_BACKCHANNEL_LOGOUT_PURPOSE = "outbound.oidc.backchannel_logout.v1"
  ENVELOPE_VERSION = 1
  ENCRYPTOR_CACHE = Concurrent::Map.new

  module_function

  def encrypt_sms_body(body)
    encrypt(body, purpose: SMS_BODY_PURPOSE)
  end

  def decrypt_sms_body(token)
    decrypt(token, purpose: SMS_BODY_PURPOSE)
  end

  def encrypt_sms_delivery(to:, title:, body:)
    encrypt_envelope(
      { "version" => ENVELOPE_VERSION, "to" => to, "title" => title, "body" => body },
      purpose: SMS_DELIVERY_PURPOSE,
      required_keys: %w(version to title body),
    )
  end

  def decrypt_sms_delivery(token)
    decrypt_envelope(token, purpose: SMS_DELIVERY_PURPOSE, required_keys: %w(version to title body))
  end

  def encrypt_oidc_backchannel_logout(uri:, client_id:, resource_type:, subject:, sid:)
    encrypt_envelope(
      {
        "version" => ENVELOPE_VERSION,
        "uri" => uri,
        "client_id" => client_id,
        "resource_type" => resource_type,
        "subject" => subject,
        "sid" => sid,
      },
      purpose: OIDC_BACKCHANNEL_LOGOUT_PURPOSE,
      required_keys: %w(version uri client_id resource_type subject sid),
    )
  end

  def decrypt_oidc_backchannel_logout(token)
    decrypt_envelope(
      token,
      purpose: OIDC_BACKCHANNEL_LOGOUT_PURPOSE,
      required_keys: %w(version uri client_id resource_type subject sid),
    )
  end

  def encrypt_email_otp(hotp_token)
    encrypt(hotp_token, purpose: EMAIL_OTP_PURPOSE)
  end

  def decrypt_email_otp(token)
    decrypt(token, purpose: EMAIL_OTP_PURPOSE)
  end

  def encrypt_email_verification_token(token)
    encrypt(token, purpose: EMAIL_VERIFICATION_TOKEN_PURPOSE)
  end

  def decrypt_email_verification_token(token)
    decrypt(token, purpose: EMAIL_VERIFICATION_TOKEN_PURPOSE)
  end

  def encrypt_envelope(payload, purpose:, required_keys:)
    validate_envelope!(payload, required_keys:)
    encrypt(JSON.generate(payload), purpose:)
  end

  def decrypt_envelope(token, purpose:, required_keys:)
    payload = JSON.parse(decrypt(token, purpose:))
    validate_envelope!(payload, required_keys:)
    payload.symbolize_keys
  rescue JSON::ParserError, TypeError
    raise ArgumentError, "Invalid encrypted sensitive payload"
  end

  def validate_envelope!(payload, required_keys:)
    unless payload.is_a?(Hash) && payload.keys.sort == required_keys.sort
      raise ArgumentError, "Invalid sensitive payload schema"
    end
    raise ArgumentError, "Unsupported sensitive payload version" unless payload["version"] == ENVELOPE_VERSION

    required_keys.excluding("version", "subject").each do |key|
      raise ArgumentError, "Sensitive payload field #{key} cannot be blank" if payload[key].blank?
    end
  end

  def encrypt(value, purpose:)
    raise ArgumentError, "Sensitive payload cannot be blank" if value.blank?

    encryptor(purpose).encrypt_and_sign(value.to_s, purpose: purpose)
  end

  def decrypt(token, purpose:)
    raise ArgumentError, "Encrypted sensitive payload cannot be blank" if token.blank?

    encryptor(purpose).decrypt_and_verify(token, purpose: purpose)
  end

  def encryptor(purpose)
    ENCRYPTOR_CACHE.compute_if_absent(purpose) do
      secret_credential = Rails.application.secret_key_base
      key_len = ActiveSupport::MessageEncryptor.key_len
      key = ActiveSupport::KeyGenerator.new(secret_credential).generate_key(purpose, key_len)
      ActiveSupport::MessageEncryptor.new(key, cipher: "aes-256-gcm")
    end
  end
end
