# typed: false
# frozen_string_literal: true

ProcessorErasureVerifiedReceipt =
  Data.define(
    :processor_key,
    :notification_public_id,
    :generation,
    :idempotency_key_digest,
    :receipt_id,
    :verified_at,
  ) do
    def initialize(
      processor_key:, notification_public_id:, generation:, idempotency_key_digest:, receipt_id:, verified_at:
    )
      unless generation.is_a?(Integer) || generation.is_a?(String)
        raise ArgumentError, "receipt generation must be an integer"
      end

      normalized_generation = Integer(generation)
    rescue ArgumentError, TypeError
      raise ArgumentError, "receipt generation must be an integer"
    else
      raise ArgumentError, "receipt generation must be positive" unless normalized_generation.positive?
      raise ArgumentError, "receipt processor_key is required" if processor_key.to_s.blank?
      raise ArgumentError, "receipt notification_public_id is required" if notification_public_id.to_s.blank?
      raise ArgumentError, "receipt idempotency_key_digest is required" if idempotency_key_digest.to_s.blank?
      unless /\A[0-9a-f]{64}\z/.match?(idempotency_key_digest.to_s)
        raise ArgumentError, "receipt idempotency_key_digest must be a SHA-256 hex digest"
      end
      raise ArgumentError, "receipt receipt_id is required" if receipt_id.to_s.blank?
      raise ArgumentError, "receipt verified_at is required" if verified_at.blank?

      super(
        processor_key: processor_key.to_s.freeze,
        notification_public_id: notification_public_id.to_s.freeze,
        generation: normalized_generation,
        idempotency_key_digest: idempotency_key_digest.to_s.freeze,
        receipt_id: receipt_id.to_s.freeze,
        verified_at: verified_at,
      )
    end
  end
