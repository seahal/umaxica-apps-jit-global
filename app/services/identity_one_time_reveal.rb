# typed: false
# frozen_string_literal: true

class IdentityOneTimeReveal
  PURPOSE = "identity.one_time_reveal"
  TOKEN_PURPOSE = :identity_one_time_reveal
  EXPIRES_IN = 15.minutes
  SECRET_LENGTH = 32
  DIGEST = "SHA256"

  Result = Struct.new(:token, :expires_at, keyword_init: true)
  Payload = Struct.new(:value, :metadata, keyword_init: true)

  class << self
    # Rails.cache is :null_store in test, so a reveal issued in one request could
    # never be consumed in the next. Tests need a store that actually retains the
    # payload for the redirect; development and production use Rails.cache itself,
    # which is Valkey.
    #
    # The payload is encrypted, single-use, and carries an explicit 15-minute TTL,
    # and `consume!` fails closed on a miss: an eviction costs the user a redo of
    # the flow, it does not reveal anything or leave authoritative state wrong.
    # That is what makes the cache an acceptable home for it.
    # rubocop:disable ThreadSafety/ClassAndModuleAttributes
    attr_writer :store
    # rubocop:enable ThreadSafety/ClassAndModuleAttributes

    def store
      @store_mutex ||= Mutex.new # rubocop:disable ThreadSafety/ClassInstanceVariable
      @store_mutex.synchronize { @store ||= default_store } # rubocop:disable ThreadSafety/ClassInstanceVariable
    end

    def default_store
      return Rails.cache unless Rails.cache.is_a?(ActiveSupport::Cache::NullStore)

      @null_store_mutex ||= Mutex.new # rubocop:disable ThreadSafety/ClassInstanceVariable
      @null_store_mutex.synchronize { @null_store ||= ActiveSupport::Cache::MemoryStore.new } # rubocop:disable ThreadSafety/ClassInstanceVariable
    end
  end

  def self.issue!(actor:, session_nonce:, value:, purpose:, metadata: {}, expires_in: EXPIRES_IN)
    new.issue!(
      actor: actor,
      session_nonce: session_nonce,
      value: value,
      purpose: purpose,
      metadata: metadata,
      expires_in: expires_in,
    )
  end

  def self.consume!(actor:, session_nonce:, token:, purpose:)
    new.consume!(actor: actor, session_nonce: session_nonce, token: token, purpose: purpose)
  end

  def issue!(actor:, session_nonce:, value:, purpose:, metadata:, expires_in:)
    raise ArgumentError, "actor is required" unless actor&.id
    raise ArgumentError, "session_nonce is required" if session_nonce.blank?
    raise ArgumentError, "value is required" if value.blank?
    raise ArgumentError, "purpose is required" if purpose.blank?

    jti = SecureRandom.uuid
    expires_at = Time.current + expires_in
    self.class.store.write(
      cache_key(jti),
      encrypt_payload(value: value, metadata: metadata),
      expires_in: expires_in,
    )

    Result.new(
      token: verifier.generate(
        claims(actor: actor, session_nonce: session_nonce, purpose: purpose, jti: jti),
        purpose: TOKEN_PURPOSE,
        expires_in: expires_in,
      ),
      expires_at: expires_at,
    )
  end

  def consume!(actor:, session_nonce:, token:, purpose:)
    payload = verifier.verified(token.to_s, purpose: TOKEN_PURPOSE)
    return nil unless valid_claims?(payload, actor: actor, session_nonce: session_nonce, purpose: purpose)

    key = cache_key(payload.fetch("jti"))
    encrypted = self.class.store.read(key)
    return nil if encrypted.blank?

    self.class.store.delete(key)
    decrypted = decrypt_payload(encrypted)
    Payload.new(value: decrypted.fetch("value"), metadata: decrypted.fetch("metadata", {}))
  rescue ActiveSupport::MessageVerifier::InvalidSignature, ActiveSupport::MessageEncryptor::InvalidMessage,
         KeyError, JSON::ParserError
    nil
  end

  private

  def valid_claims?(payload, actor:, session_nonce:, purpose:)
    payload.is_a?(Hash) &&
      payload["actor_type"] == actor.class.name &&
      payload["actor_id"].to_s == actor.id.to_s &&
      payload["session_nonce"].to_s == session_nonce.to_s &&
      payload["purpose"].to_s == purpose.to_s &&
      payload["jti"].present?
  end

  def claims(actor:, session_nonce:, purpose:, jti:)
    {
      "actor_type" => actor.class.name,
      "actor_id" => actor.id.to_s,
      "session_nonce" => session_nonce.to_s,
      "purpose" => purpose.to_s,
      "jti" => jti,
    }
  end

  def encrypt_payload(value:, metadata:)
    encryptor.encrypt_and_sign(
      JSON.generate({ value: value, metadata: metadata }),
      purpose: PURPOSE,
    )
  end

  def decrypt_payload(value)
    JSON.parse(encryptor.decrypt_and_verify(value, purpose: PURPOSE))
  end

  def cache_key(jti)
    "identity:one_time_reveal:#{Digest::SHA256.hexdigest(jti)}"
  end

  def verifier
    @verifier ||= ActiveSupport::MessageVerifier.new(
      Rails.application.key_generator.generate_key("#{PURPOSE}.token", SECRET_LENGTH),
      digest: DIGEST,
      serializer: JSON,
      url_safe: true,
    )
  end

  def encryptor
    @encryptor ||= ActiveSupport::MessageEncryptor.new(
      Rails.application.key_generator.generate_key("#{PURPOSE}.payload", ActiveSupport::MessageEncryptor.key_len),
      serializer: JSON,
    )
  end
end
