# frozen_string_literal: true

module RealmIdentifierEncryptionKeyProvider
  KEYS = {
    "app" => %w(APP_ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY APP_ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY_PREVIOUS
                APP_ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT),
    "com" => %w(COM_ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY COM_ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY_PREVIOUS
                COM_ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT),
    "org" => %w(ORG_ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY ORG_ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY_PREVIOUS
                ORG_ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT),
  }.freeze

  class << self
    public

    def key_provider(realm:)
      current_name, previous_name, salt_name = KEYS.fetch(realm)
      current = ENV.fetch(current_name)
      salt = ENV.fetch(salt_name)
      raise ArgumentError, "blank realm encryption configuration" if current.blank? || salt.blank?

      previous_json = ENV[previous_name]
      previous = parse_previous_keys(previous_json)
      unless previous.is_a?(Array) && previous.all? { |key| key.is_a?(String) && key.present? }
        raise ArgumentError, "realm previous encryption keys must be an array of nonempty strings"
      end

      keys =
        (previous + [current]).map do |password|
          generator = ActiveSupport::KeyGenerator.new(password, hash_digest_class: OpenSSL::Digest::SHA256)
          domain_salt = "identifier-encryption:v1:#{realm}:#{salt}"
          ActiveRecord::Encryption::Key.new(generator.generate_key(domain_salt, 32))
        end
      ActiveRecord::Encryption::KeyProvider.new(keys)
    end

    private

    def parse_previous_keys(raw)
      return [] if raw.nil?

      JSON.parse(raw)
    rescue JSON::ParserError
      raise ArgumentError, "invalid realm previous-key JSON", cause: nil
    end
  end
end
