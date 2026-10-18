# typed: false
# frozen_string_literal: true

module OutboundSensitivePayload
  EMAIL_OTP_PURPOSE = "outbound.email.otp"
  EMAIL_VERIFICATION_TOKEN_PURPOSE = "outbound.email.verification_token"
  SMS_DELIVERY_PURPOSE = "outbound.sms.delivery.v1"
  ENVELOPE_VERSION = 1
  ENCRYPTOR_CACHE = Concurrent::Map.new

  module_function

  def encrypt_sms_delivery(to:, title:, body:, otp_binding: nil, otp_code: nil)
    if otp_binding.is_a?(Array) && otp_binding[1] == "sign_up"
      payload = {
        "version" => 3,
        "to" => to,
        "title" => title,
        "body" => body,
        "otp_binding" => otp_binding,
        "otp_code" => otp_code,
      }
      validate_signup_sms_envelope!(payload)
      return encrypt(JSON.generate(payload), purpose: SMS_DELIVERY_PURPOSE)
    end
    unless otp_binding.nil?
      payload = {
        "version" => 4,
        "to" => to,
        "title" => title,
        "body" => body,
        "otp_binding" => otp_binding,
        "otp_code" => otp_code,
      }
      validate_registration_sms_envelope!(payload)
      return encrypt(JSON.generate(payload), purpose: SMS_DELIVERY_PURPOSE)
    end
    raise ArgumentError, "SMS code requires a typed Telephone binding" unless otp_code.nil?

    encrypt_envelope(
      { "version" => ENVELOPE_VERSION, "to" => to, "title" => title, "body" => body },
      purpose: SMS_DELIVERY_PURPOSE,
      required_keys: %w(version to title body),
    )
  end

  def decrypt_sms_delivery(token)
    payload = JSON.parse(decrypt(token, purpose: SMS_DELIVERY_PURPOSE))
    if payload.is_a?(Hash) && payload["version"] == 3
      validate_signup_sms_envelope!(payload)
    elsif payload.is_a?(Hash) && payload["version"] == 4
      validate_registration_sms_envelope!(payload)
    else
      validate_envelope!(payload, required_keys: %w(version to title body))
    end
    payload.symbolize_keys
  rescue JSON::ParserError, TypeError
    raise ArgumentError, "Invalid encrypted sensitive payload"
  end

  def validate_signup_sms_envelope!(payload)
    unless payload.is_a?(Hash) && payload.keys.sort == %w(version to title body otp_binding otp_code).sort &&
        payload["version"] == 3
      raise ArgumentError, "Invalid Telephone signup SMS payload schema"
    end

    %w(to title body).each do |key|
      unless payload[key].is_a?(String) && payload[key].valid_encoding? && payload[key].present?
        raise ArgumentError, "Invalid Telephone signup SMS payload field #{key}"
      end
    end
    TelephoneSignUpOtpDeliveryBindingValue.for_sms(otp_binding: payload.fetch("otp_binding"))
    code = payload.fetch("otp_code")
    unless code.is_a?(String) && code.encoding.ascii_compatible? && code.valid_encoding? &&
        code.match?(/\A[0-9]{6}\z/)
      raise ArgumentError, "Invalid Telephone signup SMS code"
    end

    allowed_bodies = ["Your verification code: #{code}", I18n.t("sign.telephone_verification.sms_message", code: code)]
    return if payload.fetch("title") == "Verification code" && allowed_bodies.include?(payload.fetch("body"))

    raise ArgumentError, "Telephone signup SMS message mismatch"

  end

  def validate_registration_sms_envelope!(payload)
    unless payload.is_a?(Hash) && payload.keys.sort == %w(version to title body otp_binding otp_code).sort &&
        payload["version"] == 4
      raise ArgumentError, "Invalid Telephone registration SMS payload schema"
    end

    %w(to title body).each do |key|
      unless payload[key].is_a?(String) && payload[key].valid_encoding? && payload[key].present?
        raise ArgumentError, "Invalid Telephone registration SMS payload field #{key}"
      end
    end
    TelephoneCredentialRegistrationOtpDeliveryBindingValue.for_sms(otp_binding: payload.fetch("otp_binding"))
    code = payload.fetch("otp_code")
    unless code.is_a?(String) && code.encoding.ascii_compatible? && code.valid_encoding? &&
        code.match?(/\A[0-9]{6}\z/)
      raise ArgumentError, "Invalid Telephone registration SMS code"
    end

    messages =
      I18n.available_locales.map do |locale|
        I18n.t("sign.telephone_verification.sms_message", code: code, locale: locale)
      end
    messages << "Your verification code: #{code}"
    return if payload.fetch("title") == "Verification code" && messages.include?(payload.fetch("body"))

    raise ArgumentError, "Telephone registration SMS message mismatch"
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

  def validate_envelope!(payload, required_keys:)
    unless payload.is_a?(Hash) && payload.keys.sort == required_keys.sort
      raise ArgumentError, "Invalid sensitive payload schema"
    end
    raise ArgumentError, "Unsupported sensitive payload version" unless payload["version"] == ENVELOPE_VERSION

    required_keys.excluding("version").each do |key|
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
