# frozen_string_literal: true

require_relative "observability_redactor"

module ObservabilitySpanScrubber
  module_function

  SENSITIVE_ATTRIBUTE_KEYS = %w(
    http.url http.target http.route http.request.body http.request.method
    http.request.header.authorization http.request.header.cookie
    http.response.header.set-cookie
    url uri request_uri original_url query_string
    authorization cookie set-cookie token access_token id_token refresh_token
  ).freeze

  def scrub(span)
    attributes = span.attributes
    return span unless attributes.is_a?(Hash)

    scrubbed_attributes =
      attributes.each_with_object({}) do |(key, value), result|
        result[key] = scrub_attribute(key, value)
      end

    if span.respond_to?(:attributes=)
      span.attributes = scrubbed_attributes
    else
      span.instance_variable_set(:@attributes, scrubbed_attributes)
    end

    span
  end

  def scrub_attribute(key, value)
    return ObservabilityRedactor::REDACTED if sensitive_attribute_key?(key)

    case value
    when Hash, Array, String
      ObservabilityRedactor.scrub(value)
    else
      value
    end
  end

  def sensitive_attribute_key?(key)
    normalized = key.to_s.tr("-", "_").downcase
    return true if SENSITIVE_ATTRIBUTE_KEYS.include?(normalized)
    return true if normalized.start_with?("email.") && normalized != "email.x_mailer"
    return true if normalized == "args" || normalized.end_with?(".args")

    normalized.include?("authorization") || normalized.include?("cookie")
  end
end
