# frozen_string_literal: true

require "argon2"
require "openssl"

class IdentifierHistoryFingerprintVerifier
  FINGERPRINT_FORMAT = /\A\$argon2id\$v=19\$m=65536,t=3,p=4\$[A-Za-z0-9+\/]{22}\$[A-Za-z0-9+\/]{43}\z/
  LIVE_HMAC_KEY_NAMES = %w(
    APP_EMAIL_ADDRESS_HMAC_KEY COM_EMAIL_ADDRESS_HMAC_KEY ORG_EMAIL_ADDRESS_HMAC_KEY
    APP_TELEPHONE_NUMBER_HMAC_KEY COM_TELEPHONE_NUMBER_HMAC_KEY ORG_TELEPHONE_NUMBER_HMAC_KEY
  ).freeze
  private_constant :LIVE_HMAC_KEY_NAMES

  class << self
    public

    def create(identifier:, realm:, channel:)
      key_name = history_key_name(realm:, channel:)
      normalized = normalize(identifier, channel: channel.to_s)
      raise ArgumentError, "invalid history identifier" unless normalized

      Argon2::Password.create(
        keyed_identifier(normalized, realm: realm.to_s, channel: channel.to_s, key_name:),
        t_cost: 3, m_cost: 16, p_cost: 4,
      )
    end

    def matches?(fingerprint:, identifier:, realm:, channel:)
      key_name = history_key_name(realm:, channel:)
      normalized = normalize(identifier, channel: channel.to_s)
      return false unless normalized && fingerprint.is_a?(String) && fingerprint.valid_encoding? &&
        FINGERPRINT_FORMAT.match?(fingerprint)

      verifier = keyed_identifier(normalized, realm: realm.to_s, channel: channel.to_s, key_name:)
      Argon2::Password.verify_password(verifier, fingerprint)
    end

    private

    def history_key_name(realm:, channel:)
      unless (realm.is_a?(String) || realm.is_a?(Symbol)) && (channel.is_a?(String) || channel.is_a?(Symbol))
        raise ArgumentError, "unsupported history identifier domain"
      end

      case [realm.to_s, channel.to_s]
      when ["app", "email"] then "APP_EMAIL_HISTORY_KEY"
      when ["com", "email"] then "COM_EMAIL_HISTORY_KEY"
      when ["org", "email"] then "ORG_EMAIL_HISTORY_KEY"
      when ["app", "telephone"] then "APP_TELEPHONE_HISTORY_KEY"
      when ["com", "telephone"] then "COM_TELEPHONE_HISTORY_KEY"
      when ["org", "telephone"] then "ORG_TELEPHONE_HISTORY_KEY"
      else raise ArgumentError, "unsupported history identifier domain"
      end
    end

    def normalize(identifier, channel:)
      return unless identifier.is_a?(String) && identifier.valid_encoding? && identifier.index("\0").nil?

      case channel
      when "email"
        normalized = JitUtilsEmailValidator.normalize(identifier)
        normalized if normalized && JitUtilsEmailValidator.valid?(normalized)
      when "telephone"
        normalized = TelephoneNormalization.normalize_to_e164(identifier.strip)
        normalized if normalized && TelephoneNormalization::E164_FORMAT.match?(normalized)
      else raise ArgumentError, "unsupported history identifier channel"
      end
    end

    def keyed_identifier(normalized, realm:, channel:, key_name:)
      key = ENV.fetch(key_name)
      raise KeyError, "Missing key: #{key_name}" if key.strip.empty?

      LIVE_HMAC_KEY_NAMES.each do |live_key_name|
        credential_key = Rails.app.creds.option(live_key_name.to_sym)
        if key == credential_key
          raise ArgumentError, "history key must be distinct from live identifier keys"
        end

        live_key = ENV[live_key_name]
        next if live_key.nil?

        raise ArgumentError, "history key must be distinct from live identifier keys" if key == live_key
      end

      OpenSSL::HMAC.hexdigest("SHA256", key, "identifier-history:v1:#{realm}:#{channel}:#{normalized}")
    end
  end
end
