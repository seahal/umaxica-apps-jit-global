# typed: false
# frozen_string_literal: true

module JitIdHostEnv
  class MissingHostError < StandardError; end

  module_function

  def service_url
    ENV["PRIVATE_AUTH_SERVICE_URL"].presence
  end

  def staff_url
    ENV["PRIVATE_AUTH_STAFF_URL"].presence
  end

  def validate!
    missing_keys = []
    missing_keys << "PRIVATE_AUTH_SERVICE_URL" if service_url.blank?
    missing_keys << "PRIVATE_AUTH_STAFF_URL" if staff_url.blank?
    return if missing_keys.empty?

    raise MissingHostError, "Missing required id host env: #{missing_keys.join(", ")}"
  end
end
