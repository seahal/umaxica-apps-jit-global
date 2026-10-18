# typed: false
# frozen_string_literal: true

ProcessorErasureDispatchResult =
  Data.define(:outcome, :receipt, :error_code, :error_message) do
    def self.received(receipt:)
      raise ArgumentError, "a verified receipt is required" unless receipt.is_a?(ProcessorErasureVerifiedReceipt)

      new(outcome: :received, receipt: receipt, error_code: nil, error_message: nil)
    end

    def self.accepted_without_receipt
      new(outcome: :accepted_pending, receipt: nil, error_code: nil, error_message: nil)
    end

    def self.retryable(code:, message:)
      new(
        outcome: :retryable_failure,
        receipt: nil,
        error_code: code.to_s,
        error_message: sanitized_error_message(message),
      )
    end

    def self.permanent(code:, message:)
      new(
        outcome: :permanent_failure,
        receipt: nil,
        error_code: code.to_s,
        error_message: sanitized_error_message(message),
      )
    end

    def self.sanitized_error_message(message)
      ChronicleRecordPolicy.sanitize_text(message.to_s).to_s
    end

    def self.normalized_error_code(code)
      normalized = code.to_s
      unless normalized.match?(/\A[a-z][a-z0-9_.-]{0,63}\z/)
        raise ArgumentError, "failure outcome requires a safe error code"
      end

      normalized
    end

    def initialize(outcome:, receipt:, error_code:, error_message:)
      normalized_outcome = outcome.to_sym if outcome.respond_to?(:to_sym)
      supported_outcomes = %i(received accepted_pending retryable_failure permanent_failure)
      raise ArgumentError, "unsupported dispatch outcome" unless supported_outcomes.include?(normalized_outcome)
      if normalized_outcome == :received && !receipt.is_a?(ProcessorErasureVerifiedReceipt)
        raise ArgumentError, "received outcome requires a verified receipt"
      end

      normalized_error_code =
        if %i(received accepted_pending).include?(normalized_outcome)
          nil
        else
          self.class.normalized_error_code(error_code)
        end

      unless %i(received accepted_pending).include?(normalized_outcome) || normalized_error_code.present?
        raise ArgumentError, "failure outcome requires an error code"
      end

      super(
        outcome: normalized_outcome,
        receipt: receipt,
        error_code: normalized_error_code,
        error_message: self.class.sanitized_error_message(error_message),
      )
    end
  end
