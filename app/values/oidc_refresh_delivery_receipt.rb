# typed: false
# frozen_string_literal: true

class OidcRefreshDeliveryReceipt < Data.define(
  :rp_session_public_id,
  :client_id,
  :resource_type,
  :predecessor_digest,
  :generation,
  :expires_at,
  :access_expires_at,
  :refresh_expires_at,
  :token_response,
  :attempt_ref,
)
  PURPOSE = "rp_refresh_delivery_receipt"
  # Version 2 (R5-WU08) binds the RP's refresh attempt reference so a delivery query can only
  # recover the exact attempt that dispatched. Receipts live five seconds, so no v1 reader is kept.
  VERSION = 2
  TTL = 5.seconds
  TOKEN_FIELDS = %i(access_token token_type expires_in refresh_token refresh_token_expires_in id_token).freeze
  REQUIRED_TOKEN_FIELDS = %i(access_token token_type expires_in refresh_token refresh_token_expires_in).freeze
  PAYLOAD_FIELDS = %w(
    version rp_session_public_id client_id resource_type predecessor_digest generation expires_at
    access_expires_at refresh_expires_at token_response attempt_ref
  ).freeze

  class Invalid < StandardError; end

  class << self
    public

    def encrypt(rp_session_public_id:, client_id:, resource_type:, predecessor_digest:, generation:, expires_at:,
                access_expires_at:, refresh_expires_at:, token_response:, attempt_ref:)
      receipt = build(
        rp_session_public_id:, client_id:, resource_type:, predecessor_digest:, generation:, expires_at:,
        access_expires_at:, refresh_expires_at:, token_response:, attempt_ref:,
      )
      encryptor.encrypt_and_sign(payload_for(receipt), purpose: PURPOSE)
    rescue ActiveSupport::MessageEncryptor::InvalidMessage, ArgumentError, KeyError, TypeError => e
      raise Invalid, "RP refresh delivery receipt cannot be encrypted", cause: e
    end

    def decrypt(ciphertext)
      raise Invalid, "RP refresh delivery receipt is blank" if ciphertext.blank?

      payload = encryptor.decrypt_and_verify(ciphertext, purpose: PURPOSE)
      build_from_payload(payload)
    rescue ActiveSupport::MessageEncryptor::InvalidMessage, ArgumentError, KeyError, TypeError => e
      raise Invalid, "RP refresh delivery receipt cannot be decrypted", cause: e
    end

    private

    # attempt_ref is nil when the caller did not supply one (an in-process OP-side reissue); such a
    # receipt can be redelivered on the refresh endpoint but never matched by a delivery query.
    def build(rp_session_public_id:, client_id:, resource_type:, predecessor_digest:, generation:, expires_at:,
              access_expires_at:, refresh_expires_at:, token_response:, attempt_ref:)
      unless attempt_ref.nil? || (attempt_ref.is_a?(String) && attempt_ref.match?(/\A[A-Za-z0-9_-]{1,64}\z/))
        raise ArgumentError, "RP refresh receipt attempt reference is invalid"
      end

      raise ArgumentError, "RP refresh receipt session binding is missing" if rp_session_public_id.blank?
      raise ArgumentError, "RP refresh receipt client binding is missing" if client_id.blank?
      raise ArgumentError, "RP refresh receipt realm binding is missing" if resource_type.blank?
      raise ArgumentError, "RP refresh receipt predecessor is missing" if predecessor_digest.blank?
      raise ArgumentError,
            "RP refresh receipt generation is invalid" unless generation.is_a?(Integer) && generation.positive?

      expires_at = require_time(expires_at, "receipt expiry")
      access_expires_at = require_time(access_expires_at, "access expiry")
      refresh_expires_at = require_time(refresh_expires_at, "refresh expiry")
      raise ArgumentError, "RP refresh receipt expiry is reversed" if refresh_expires_at < access_expires_at

      token_response = normalize_token_response(token_response)
      new(
        rp_session_public_id: rp_session_public_id.to_s,
        client_id: client_id.to_s,
        resource_type: resource_type.to_s,
        predecessor_digest: predecessor_digest.to_s,
        generation: generation,
        expires_at: expires_at,
        access_expires_at: access_expires_at,
        refresh_expires_at: refresh_expires_at,
        token_response: token_response,
        attempt_ref: attempt_ref,
      )
    end

    def build_from_payload(payload)
      raise ArgumentError, "RP refresh receipt payload must be an object" unless payload.is_a?(Hash)
      raise ArgumentError, "RP refresh receipt version is invalid" unless payload.keys.sort == PAYLOAD_FIELDS.sort
      raise ArgumentError, "RP refresh receipt version is invalid" unless payload.fetch("version") == VERSION

      build(
        rp_session_public_id: payload.fetch("rp_session_public_id"),
        client_id: payload.fetch("client_id"),
        resource_type: payload.fetch("resource_type"),
        predecessor_digest: payload.fetch("predecessor_digest"),
        generation: payload.fetch("generation"),
        expires_at: Time.iso8601(payload.fetch("expires_at")),
        access_expires_at: Time.iso8601(payload.fetch("access_expires_at")),
        refresh_expires_at: Time.iso8601(payload.fetch("refresh_expires_at")),
        token_response: payload.fetch("token_response"),
        attempt_ref: payload.fetch("attempt_ref"),
      )
    end

    def payload_for(receipt)
      {
        "version" => VERSION,
        "rp_session_public_id" => receipt.rp_session_public_id,
        "client_id" => receipt.client_id,
        "resource_type" => receipt.resource_type,
        "predecessor_digest" => receipt.predecessor_digest,
        "generation" => receipt.generation,
        "expires_at" => receipt.expires_at.iso8601(6),
        "access_expires_at" => receipt.access_expires_at.iso8601(6),
        "refresh_expires_at" => receipt.refresh_expires_at.iso8601(6),
        "token_response" => receipt.token_response.stringify_keys,
        "attempt_ref" => receipt.attempt_ref,
      }
    end

    def normalize_token_response(value)
      raise ArgumentError, "RP refresh token response must be an object" unless value.is_a?(Hash)

      unknown = value.keys.map(&:to_s) - TOKEN_FIELDS.map(&:to_s)
      raise ArgumentError, "RP refresh token response has unknown fields" if unknown.any?

      response = {}
      TOKEN_FIELDS.each do |key|
        raw = value[key] || value[key.to_s]
        next if raw.nil? && key == :id_token
        raise ArgumentError, "RP refresh token response is incomplete" if raw.nil? || raw == ""

        response[key] = raw
      end
      REQUIRED_TOKEN_FIELDS.each do |key|
        value = response.fetch(key)
        unless key.in?(%i(expires_in refresh_token_expires_in))
          raise ArgumentError, "RP refresh token response contains a blank value" if value.to_s.blank?

          next
        end

        seconds = value.is_a?(Integer) ? value : Integer(value.to_s, 10)
        raise ArgumentError, "RP refresh token response expiry is invalid" if seconds.negative?

        response[key] = seconds
      end
      response
    rescue ArgumentError, TypeError
      raise ArgumentError, "RP refresh token response is invalid"
    end

    def require_time(value, label)
      time = value.to_time
      raise ArgumentError, "#{label} is invalid" unless time

      time.utc
    rescue NoMethodError, TypeError
      raise ArgumentError, "#{label} is invalid"
    end

    def encryptor
      key = Rails.application.key_generator.generate_key(PURPOSE, 32)
      ActiveSupport::MessageEncryptor.new(key, cipher: "aes-256-gcm", serializer: JSON)
    end
  end

  public

  def active_at?(now)
    expires_at > now.to_time
  end

  def matches?(rp_session_public_id:, client_id:, resource_type:, predecessor_digest:, generation:)
    secure_equal?(rp_session_public_id, self.rp_session_public_id) &&
      secure_equal?(client_id, self.client_id) &&
      secure_equal?(resource_type, self.resource_type) &&
      secure_equal?(predecessor_digest, self.predecessor_digest) &&
      generation == self.generation
  end

  # A delivery query must name the exact attempt that dispatched this rotation.
  def attempt_matches?(attempt_ref)
    self.attempt_ref.present? && secure_equal?(attempt_ref.to_s, self.attempt_ref)
  end

  # Re-delivery returns the exact issued response. Callers use the absolute
  # deadlines below when setting browser cookies.
  # The exact issued response is a snapshot; retain the existing time keyword for callers that
  # already have the database decision time.
  # The snapshot does not change with elapsed time.
  def token_response_for(now:)
    token_response.dup
  end

  def remaining_expiries(now:)
    {
      access_expires_at: access_expires_at,
      refresh_expires_at: refresh_expires_at,
      access_remaining_seconds: remaining_seconds(access_expires_at, now),
      refresh_remaining_seconds: remaining_seconds(refresh_expires_at, now),
    }
  end

  private

  def remaining_seconds(deadline, now)
    [(deadline - now.to_time).to_i, 0].max
  end

  def secure_equal?(left, right)
    left = left.to_s
    right = right.to_s
    return false unless left.bytesize == right.bytesize

    ActiveSupport::SecurityUtils.secure_compare(left, right)
  end
end
