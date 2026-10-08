# typed: false
# frozen_string_literal: true

require "openssl"

module IdentifierBlindIndex
  module_function

  EMAIL_KEYS = {
    "app" => :APP_EMAIL_ADDRESS_HMAC_KEY,
    "com" => :COM_EMAIL_ADDRESS_HMAC_KEY,
    "org" => :ORG_EMAIL_ADDRESS_HMAC_KEY,
  }.freeze
  TELEPHONE_KEYS = {
    "app" => :APP_TELEPHONE_NUMBER_HMAC_KEY,
    "com" => :COM_TELEPHONE_NUMBER_HMAC_KEY,
    "org" => :ORG_TELEPHONE_NUMBER_HMAC_KEY,
  }.freeze

  def normalize_email(value)
    return nil if value.nil?
    raise ArgumentError, "email identifier must be a string" unless value.is_a?(String)
    return nil unless value.valid_encoding? && value.exclude?("\0")

    JitUtilsEmailValidator.normalize(value)
  end

  def normalize_telephone(value)
    return nil if value.nil?
    raise ArgumentError, "telephone identifier must be a string" unless value.is_a?(String)
    return nil unless value.valid_encoding? && value.exclude?("\0")

    normalized = TelephoneNormalization.normalize_to_e164(value.strip)
    return nil unless normalized && TelephoneNormalization::E164_FORMAT.match?(normalized)

    normalized
  end

  def bidx_for_email(value, realm:)
    key = EMAIL_KEYS.fetch(realm.to_s) { raise ArgumentError, "unsupported identifier realm" }
    normalized = normalize_email(value)
    return nil if normalized.blank?

    digest("#{realm}:email", normalized, required_secret_credential(key))
  end

  def bidx_for_telephone(value, realm:)
    key = TELEPHONE_KEYS.fetch(realm.to_s) { raise ArgumentError, "unsupported identifier realm" }
    normalized = normalize_telephone(value)
    return nil if normalized.blank?

    digest("#{realm}:telephone", normalized, required_secret_credential(key))
  end

  def digest(kind, normalized_identifier, secret_credential_value)
    OpenSSL::HMAC.hexdigest("SHA256", secret_credential_value, "#{kind}:#{normalized_identifier}")
  end

  def required_secret_credential(key)
    Rails.app.creds.option(key).presence || required_env_secret_credential(key)
  end

  def required_env_secret_credential(key)
    ENV.fetch(key.to_s).presence || raise_missing_secret_credential(key)
  rescue KeyError
    raise_missing_secret_credential(key)
  end

  def raise_missing_secret_credential(key)
    raise KeyError, "Missing key: [:#{key}]"
  end
end
