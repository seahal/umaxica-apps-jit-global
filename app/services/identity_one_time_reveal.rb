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
    SecurityOneTimeReveal.create!(
      jti_digest: digest(jti),
      actor_type: actor.class.name,
      actor_id: actor.id,
      session_nonce_digest: digest(session_nonce),
      purpose: purpose,
      encrypted_payload: encrypt_payload(value: value, metadata: metadata),
      expires_at: expires_at,
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

    encrypted = AppTicketRecord.connected_to(role: :writing) do
      SecurityOneTimeReveal.consume(
        jti_digest: digest(payload.fetch("jti")),
        actor_type: actor.class.name,
        actor_id: actor.id,
        session_nonce_digest: digest(session_nonce),
        purpose: purpose,
      )
    end
    return nil if encrypted.blank?

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

  def digest(value)
    Digest::SHA256.hexdigest(value.to_s)
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
