# typed: false
# frozen_string_literal: true

class JwtAnomalySubscriber
  METADATA_KEYS = [].freeze
  MAX_ERROR_MESSAGE_LENGTH = 1000

  def emit(event)
    return unless event.respond_to?(:name) && event.name == "jwt.anomaly.detected"

    payload = event.payload
    return if payload.blank?

    unless payload.is_a?(Hash)
      log_invalid_payload(payload_class: payload.class.name)
      return
    end

    code = payload[:reason_code] || payload["reason_code"] || payload[:code] || payload["code"]
    return if code.blank?

    normalized_code = normalize_code(code)
    unless normalized_code
      log_catalog_miss(reason_code: "INVALID", reason_code_length: code.to_s.bytesize)
      return
    end

    occurrence = JwtOccurrence.find_by(body: normalized_code)
    unless occurrence
      log_catalog_miss(reason_code: normalized_code)
      return
    end

    JwtAnomalyEvent.create!(
      jwt_occurrence: occurrence,
      code: normalized_code,
      request_host: safe_text(payload[:request_host]),
      kid: safe_text(payload[:kid]),
      alg: safe_text(payload[:alg]),
      typ: safe_text(payload[:typ]),
      issuer: safe_text(payload[:iss]),
      jti: safe_text(payload[:jti]),
      error_class: safe_text(payload[:error_class]),
      error_message: safe_error_message(payload[:error_message]),
      metadata: build_metadata(payload),
      occurred_at: occurred_at_for(event),
    )
  rescue ActiveRecord::ActiveRecordError => e
    Rails.logger.error(
      JitLogEvent.format(
        "jwt.anomaly.subscriber_failed",
        error_class: e.class.name,
        message: safe_error_message(e.message),
      ),
    )
  end

  private

  def normalize_code(code)
    value = code.to_s
    return value if /\A[A-Z][A-Z0-9_]{0,254}\z/.match?(value)

    nil
  end

  def log_catalog_miss(reason_code:, reason_code_length: nil)
    Rails.logger.error(
      JitLogEvent.format(
        "jwt.anomaly.catalog_miss",
        reason_code: reason_code,
        reason_code_length: reason_code_length,
      ),
    )
  end

  def log_invalid_payload(payload_class:)
    Rails.logger.error(
      JitLogEvent.format(
        "jwt.anomaly.invalid_payload",
        payload_class: payload_class.to_s.truncate(255),
      ),
    )
  end

  def safe_error_message(value)
    safe_text(value, max_length: MAX_ERROR_MESSAGE_LENGTH)
  end

  def safe_text(value, max_length: 255)
    ChronicleRecordPolicy.sanitize_text(value).to_s.truncate(max_length)
  end

  # ActiveSupport::Notifications::Event#time is a monotonic clock reading, not
  # wall-clock time, so only an explicit Time is trusted as the occurrence time.
  def occurred_at_for(event)
    time = event.time
    (time.is_a?(Time) || time.is_a?(ActiveSupport::TimeWithZone)) ? time : Time.current
  end

  def build_metadata(payload)
    data = payload.respond_to?(:to_h) ? payload.to_h : {}
    METADATA_KEYS.each_with_object({}) do |key, metadata|
      if data.key?(key)
        metadata[key] = data[key]
      elsif data.key?(key.to_sym)
        metadata[key] = data[key.to_sym]
      end
    end
  end
end
