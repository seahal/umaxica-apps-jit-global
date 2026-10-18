# typed: false
# frozen_string_literal: true

class ProcessorErasureRetryPolicy
  MAX_ATTEMPTS_LIMIT = 1_000

  attr_reader :max_attempts, :retry_delay_seconds

  def initialize(max_attempts:, retry_delay_seconds:)
    @max_attempts = integer_argument(max_attempts)
    @retry_delay_seconds = integer_argument(retry_delay_seconds)
    validate!
    freeze
  rescue ArgumentError, TypeError
    raise ArgumentError, "retry policy requires integer max_attempts and retry_delay_seconds"
  end

  public

  def retry_at(now:, attempt_number:)
    normalize_attempt_number(attempt_number)

    now + retry_delay_seconds
  end

  def exhausted?(attempt_number)
    normalize_attempt_number(attempt_number) >= max_attempts
  end

  private

  def normalize_attempt_number(attempt_number)
    number = integer_argument(attempt_number)
    raise ArgumentError, "attempt_number must be positive" unless number.positive?

    number
  rescue ArgumentError, TypeError
    raise ArgumentError, "attempt_number must be positive"
  end

  def integer_argument(value)
    raise ArgumentError, "value must be an integer" unless value.is_a?(Integer) || value.is_a?(String)

    Integer(value)
  rescue ArgumentError, TypeError
    raise ArgumentError, "value must be an integer"
  end

  def validate!
    unless max_attempts.between?(1, MAX_ATTEMPTS_LIMIT)
      raise ArgumentError, "max_attempts must be between 1 and #{MAX_ATTEMPTS_LIMIT}"
    end
    raise ArgumentError, "retry_delay_seconds must not be negative" if retry_delay_seconds.negative?
  end
end
