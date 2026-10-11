# typed: false
# frozen_string_literal: true

module JitSecurityJwtAnomalyReporter
  module_function

  CLAIM_REASON_MAP = {
    "iss" => "MISSING_ISS",
    "aud" => "MISSING_AUD",
    "typ" => "MISSING_TYP",
    "exp" => "MISSING_EXP",
    "nbf" => "MISSING_NBF",
    "sub" => "MISSING_SUB",
    "sid" => "MISSING_SID",
    "act" => "MISSING_ACT",
    "jti" => "MISSING_JTI",
    "public_id" => "MISSING_PUBLIC_ID",
    "preference_type" => "MISSING_PREFERENCE_TYPE",
  }.freeze
  EXTRA_KEYS = [].freeze
  MAX_DIAGNOSTIC_TEXT_LENGTH = 255
  MAX_AUDIENCE_VALUES = 8

  def report_auth(resource_type:, host:, header: {}, payload: {}, reason:, error: nil, extra: {})
    context = auth_context(resource_type)
    report(
      context: context,
      host: host,
      header: header,
      payload: payload,
      reason: reason,
      error: error,
      extra: extra,
    )
  end

  def report_preference(host:, header: {}, payload: {}, reason:, error: nil, extra: {})
    context = preference_context(host)
    report(
      context: context,
      host: host,
      header: header,
      payload: payload,
      reason: reason,
      error: error,
      extra: extra,
    )
  end

  def auth_context(resource_type)
    case resource_type.to_s
    when "client" then "AUTH_CLIENT"
    when "operator", "staff" then "AUTH_OPERATOR"
    when "visitor", "customer" then "AUTH_VISITOR"
    end
  end

  def preference_context(host)
    host_value = host.to_s.downcase
    return "APP_PREFERENCE" if host_value.include?(".app.") || host_value.start_with?("app.")
    return "COM_PREFERENCE" if host_value.include?(".com.") || host_value.start_with?("com.")
    return "ORG_PREFERENCE" if host_value.include?(".org.") || host_value.start_with?("org.")

    nil
  end

  def reason_for_missing_claim(error_message)
    claim = error_message.to_s[/Missing required claim ([A-Za-z0-9_]+)/, 1]
    CLAIM_REASON_MAP.fetch(claim, "DECODE_ERROR")
  end

  def report(context:, host:, header:, payload:, reason:, error:, extra:)
    return if context.blank? || reason.blank?

    event_payload = {
      code: "#{context}_#{reason}",
      reason_code: "#{context}_#{reason}",
      context: context,
      request_host: bounded_text(host),
      kid: bounded_text(header["kid"]),
      alg: bounded_text(header["alg"]),
      typ: bounded_text(header["typ"] || payload["typ"]),
      iss: bounded_text(payload["iss"]),
      aud: bounded_audience(payload["aud"]),
      jti: bounded_text(payload["jti"]),
      error_class: error&.class&.name,
      error_message: ChronicleRecordPolicy.sanitize_text(error&.message),
    }.merge(allowed_extra(extra))

    Rails.logger.info(JitLogEvent.format("jwt.anomaly.detected", event_payload))
    ActiveSupport::Notifications.instrument("jwt.anomaly.detected", event_payload)
  rescue StandardError => e
    Rails.logger.error(
      JitLogEvent.format(
        "jwt.anomaly.reporting_failed",
        error_class: e.class.name,
        message: bounded_text(e.message),
      ),
    )
    nil
  end

  private_class_method :auth_context, :preference_context, :report

  def bounded_text(value)
    return unless value.is_a?(String)

    ChronicleRecordPolicy.sanitize_text(value).to_s.truncate(MAX_DIAGNOSTIC_TEXT_LENGTH)
  end

  def bounded_audience(value)
    case value
    when String
      bounded_text(value)
    when Array
      value.first(MAX_AUDIENCE_VALUES).filter_map { |entry| bounded_text(entry) }
    end
  end

  private_class_method :bounded_text, :bounded_audience

  def allowed_extra(extra)
    data = extra.respond_to?(:to_h) ? extra.to_h : {}
    EXTRA_KEYS.each_with_object({}) do |key, safe_extra|
      if data.key?(key)
        safe_extra[key] = data[key]
      elsif data.key?(key.to_sym)
        safe_extra[key] = data[key.to_sym]
      end
    end
  end

  private_class_method :allowed_extra
end
