# typed: false
# frozen_string_literal: true

require "openssl"

# adr/unified-enforcement.md, HMAC / Encryption. Computes the dedicated,
# per-realm enforcement identifier digest -- deliberately not
# IdentifierBlindIndex's key, so compromising the login-lookup key does not
# yield an offline oracle over the ban list, and vice versa (D6). Digest rows
# carry no uniqueness constraint the way credential digests do, so unlike
# adr/identifier-hmac-emergency-rotation.md this key supports dual-read
# online rotation via key_version.
module EnforcementIdentifierDigest
  module_function

  CURRENT_KEY_VERSION = 1
  CURRENT_DIGEST_VERSION = 1
  CURRENT_NORMALIZATION_VERSION = 1

  REALMS = %w(app org).freeze

  def normalize_email(value)
    JitUtilsEmailValidator.normalize(value)
  end

  def normalize_telephone(value)
    TelephoneNormalization.normalize_to_e164(value.to_s.strip)
  end

  def for_email(realm:, value:)
    normalized = normalize_email(value)
    return nil if normalized.blank?

    build(realm: realm, identifier_kind: "email", normalized_identifier: normalized, display_value: normalized)
  end

  def for_telephone(realm:, value:)
    normalized = normalize_telephone(value)
    return nil if normalized.blank?

    build(realm: realm, identifier_kind: "telephone", normalized_identifier: normalized, display_value: normalized)
  end

  # Keyed on issuer + subject, matching ClientExternalIdentity's own
  # uniqueness scope (subject unique within issuer), never on email.
  def for_google_subject(realm:, issuer:, subject:)
    for_social_subject(realm: realm, identifier_kind: "google_subject", issuer: issuer, subject: subject)
  end

  def for_apple_subject(realm:, issuer:, subject:)
    for_social_subject(realm: realm, identifier_kind: "apple_subject", issuer: issuer, subject: subject)
  end

  def for_social_subject(realm:, identifier_kind:, issuer:, subject:)
    return nil if issuer.blank? || subject.blank?

    normalized = "#{issuer}:#{subject}"
    build(realm: realm, identifier_kind: identifier_kind, normalized_identifier: normalized, display_value: normalized)
  end

  def build(realm:, identifier_kind:, normalized_identifier:, display_value:)
    {
      identifier_kind: identifier_kind,
      lookup_digest: digest(realm, identifier_kind, normalized_identifier),
      key_version: CURRENT_KEY_VERSION,
      digest_version: CURRENT_DIGEST_VERSION,
      normalization_version: CURRENT_NORMALIZATION_VERSION,
      display_value: display_value,
    }
  end

  def digest(realm, identifier_kind, normalized_identifier)
    OpenSSL::HMAC.hexdigest("SHA256", key_for(realm), "#{identifier_kind}:#{normalized_identifier}")
  end

  def key_for(realm)
    raise ArgumentError, "Unsupported realm: #{realm}" unless REALMS.include?(realm.to_s)

    required_secret_credential(:"ENFORCEMENT_#{realm.to_s.upcase}_IDENTIFIER_HMAC_KEY")
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
