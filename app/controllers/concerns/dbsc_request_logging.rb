# typed: false
# frozen_string_literal: true

module DbscRequestLogging
  extend ActiveSupport::Concern

  private

  def log_dbsc_request_observability!
    header_names = dbsc_observable_header_names
    return if header_names.empty?

    Rails.logger.info(
      JitLogEvent.format(
        "dbsc.request",
        request_method: request.request_method,
        request_path: request.path,
        header_names: header_names.sort,
      ),
    )
  end

  def dbsc_observable_header_names
    header_names = [
      AuthIoKeys::Headers::DBSC_REGISTRATION,
      AuthIoKeys::Headers::DBSC_RESPONSE,
      AuthIoKeys::Headers::DBSC_SESSION_ID,
      AuthIoKeys::Headers::DBSC_CHALLENGE,
      "Secure-Session-Registration",
      "Secure-Session-Response",
      "Secure-Session-Skipped",
      "Secure-Session-Id",
      "Secure-Session-Challenge",
      "Sec-Secure-Session-Id",
      "Sec-Secure-Session-Challenge",
      "Sec-Session-Registration",
      "Sec-Session-Response",
      "Sec-Session-Skipped",
      "Sec-Session-Id",
      "Sec-Session-Challenge",
    ].uniq

    header_names.select { |name| request.headers[name].present? }
  end
end
