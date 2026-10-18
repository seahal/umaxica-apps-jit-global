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

  def self.resume_for_operation!(actor:, session_nonce:, purpose:, operation_ref:)
    new.resume_for_operation!(
      actor: actor, session_nonce: session_nonce, purpose: purpose,
      operation_ref: operation_ref,
    )
  end

  def self.consume!(actor:, session_nonce:, token:, purpose:)
    new.consume!(actor: actor, session_nonce: session_nonce, token: token, purpose: purpose)
  end

  public_class_method :resume_for_operation!

  def issue!(actor:, session_nonce:, value:, purpose:, metadata:, expires_in:)
    raise ArgumentError, "actor is required" unless actor&.id
    raise ArgumentError, "session_nonce is required" if session_nonce.blank?
    raise ArgumentError, "value is required" if value.blank?
    raise ArgumentError, "purpose is required" if purpose.blank?

    raise ArgumentError, "metadata must be a hash" unless metadata.is_a?(Hash)

    metadata = metadata.stringify_keys
    raise ArgumentError, "delivery token is server-owned" if metadata.key?("delivery_token")
    if metadata.key?("delivery_operation_ref") &&
        !(metadata["delivery_operation_ref"].is_a?(String) && metadata["delivery_operation_ref"].present?)
      raise ArgumentError, "delivery operation is invalid"
    end

    jti = SecureRandom.uuid
    expires_at = SecurityOneTimeReveal.database_now + expires_in
    token = verifier.generate(
      claims(actor: actor, session_nonce: session_nonce, purpose: purpose, jti: jti),
      purpose: TOKEN_PURPOSE, expires_in: expires_in,
    )
    if metadata.key?("delivery_operation_ref")
      metadata = metadata.merge("delivery_token" => token)
    end
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
      token: token,
      expires_at: expires_at,
    )
  end

  def resume_for_operation!(actor:, session_nonce:, purpose:, operation_ref:)
    raise ArgumentError, "reveal operation is required" unless actor&.id && session_nonce.present? &&
      purpose.present? && operation_ref.is_a?(String) && operation_ref.present?

    matches =
      SecurityOneTimeReveal.where(
        actor_type: actor.class.name, actor_id: actor.id, session_nonce_digest: digest(session_nonce),
        purpose: purpose, consumed_at: nil,
      ).where("expires_at > ?", SecurityOneTimeReveal.database_now).filter_map do |record|
        metadata = decrypt_payload(record.encrypted_payload).fetch("metadata")
        next unless metadata["delivery_operation_ref"] == operation_ref

        token = metadata.fetch("delivery_token")
        payload = verifier.verified(token, purpose: TOKEN_PURPOSE)
        unless valid_claims?(payload, actor: actor, session_nonce: session_nonce, purpose: purpose) &&
            digest(payload.fetch("jti")) == record.jti_digest
          raise ArgumentError, "reveal delivery binding is invalid"
        end

        Result.new(token: token, expires_at: record.expires_at)
      end
    raise ArgumentError, "reveal operation has multiple deliveries" if matches.length > 1

    matches.first
  end

  public :resume_for_operation!

  def consume!(actor:, session_nonce:, token:, purpose:)
    payload = verifier.verified(token.to_s, purpose: TOKEN_PURPOSE)
    return nil unless valid_claims?(payload, actor: actor, session_nonce: session_nonce, purpose: purpose)

    encrypted =
      OpBaseAppRecord.connected_to(role: :writing) do
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
    Payload.new(
      value: decrypted.fetch("value"),
      metadata: decrypted.fetch("metadata", {}).except(
        "delivery_operation_ref",
        "delivery_token",
      ),
    )
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
