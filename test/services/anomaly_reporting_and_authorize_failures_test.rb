# typed: false
# frozen_string_literal: true

require "test_helper"

# Two boundaries whose whole job is to not make a bad situation worse: a JWT
# anomaly report that itself fails must be swallowed rather than replacing the
# anomaly it was reporting, and an authorization request that fails to persist
# has to answer the OAuth error the client can act on rather than raising.
class AnomalyReportingAndAuthorizeFailuresTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test "a failure while reporting a JWT anomaly is swallowed rather than replacing it" do
    unavailable = Object.new
    unavailable.define_singleton_method(:warn) { |*| raise IOError, "log sink unavailable" }
    unavailable.define_singleton_method(:info) { |*| raise IOError, "log sink unavailable" }
    unavailable.define_singleton_method(:error) { |*| nil }

    Rails.stub(:logger, unavailable) do
      assert_nil JitSecurityJwtAnomalyReporter.report_auth(
        resource_type: "client", host: "auth.umaxica.app", reason: "MISSING_ISS",
      )
    end
  end

  test "a JWT anomaly reporting failure does not log a raw token-shaped message" do
    raw_jwt = "eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiJzZWNyZXQifQ.signature-value"
    logged_message = nil
    logger = Object.new
    logger.define_singleton_method(:info) do |_message|
      raise IOError, "report failed #{raw_jwt}"
    end
    logger.define_singleton_method(:error) { |message| logged_message = message }

    Rails.stub(:logger, logger) do
      assert_nil JitSecurityJwtAnomalyReporter.report_auth(
        resource_type: "client", host: "auth.umaxica.app", reason: "MISSING_ISS",
      )
    end

    assert_not_nil logged_message
    assert_not_includes logged_message, raw_jwt
    assert_includes logged_message, "[FILTERED]"
  end

  test "a JWT anomaly is reported with the claim names that were missing" do
    reported = []
    logger = Object.new
    logger.define_singleton_method(:warn) { |message| reported << message }
    logger.define_singleton_method(:info) { |message| reported << message }
    logger.define_singleton_method(:error) { |message| reported << message }

    Rails.stub(:logger, logger) do
      JitSecurityJwtAnomalyReporter.report_auth(
        resource_type: "client", host: "auth.umaxica.app", reason: "MISSING_ISS",
        payload: { "aud" => "umaxica-api" },
      )
    end

    assert_predicate reported, :present?
    assert(reported.any? { |message| message.to_s.include?("MISSING_ISS") })
  end

  test "a missing nbf claim uses the catalog reason" do
    assert_equal "MISSING_NBF",
                 JitSecurityJwtAnomalyReporter.reason_for_missing_claim("Missing required claim nbf")
  end

  test "a JWT anomaly is published to the notification boundary" do
    payloads = []
    callback = ->(_name, _start, _finish, _id, payload) { payloads << payload }

    ActiveSupport::Notifications.subscribed(callback, "jwt.anomaly.detected") do
      JitSecurityJwtAnomalyReporter.report_auth(
        resource_type: "client", host: "auth.umaxica.app", reason: "MISSING_ISS",
      )
    end

    payload = payloads.fetch(0)

    assert_equal "AUTH_CLIENT_MISSING_ISS", payload.fetch(:reason_code)
  end

  test "a JWT anomaly notification does not carry raw error tokens or unallowlisted extras" do
    raw_jwt = "eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiJzZWNyZXQifQ.signature-value"
    payloads = []
    callback = ->(_name, _start, _finish, _id, payload) { payloads << payload }

    ActiveSupport::Notifications.subscribed(callback, "jwt.anomaly.detected") do
      JitSecurityJwtAnomalyReporter.report_auth(
        resource_type: "client",
        host: "auth.umaxica.app",
        reason: "DECODE_FAILED",
        error: StandardError.new("invalid token #{raw_jwt}"),
        extra: { raw_payload: raw_jwt },
      )
    end

    payload = payloads.fetch(0)

    assert_not_includes payload.fetch(:error_message), raw_jwt
    assert_includes payload.fetch(:error_message), "[FILTERED]"
    assert_not payload.key?(:raw_payload)
  end

  test "a JWT anomaly notification bounds untrusted diagnostic fields" do
    raw_jwt = "eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiJzZWNyZXQifQ.signature-value"
    oversized_value = "a" * 256
    payloads = []
    callback = ->(_name, _start, _finish, _id, payload) { payloads << payload }

    ActiveSupport::Notifications.subscribed(callback, "jwt.anomaly.detected") do
      JitSecurityJwtAnomalyReporter.report_auth(
        resource_type: "client",
        host: "auth.umaxica.app",
        header: { "kid" => raw_jwt, "alg" => oversized_value, "typ" => oversized_value },
        payload: { "iss" => raw_jwt, "aud" => Array.new(20, oversized_value), "jti" => oversized_value },
        reason: "CLAIM_INVALID",
      )
    end

    payload = payloads.fetch(0)

    assert_equal 8, payload.fetch(:aud).length
    assert_operator payload.fetch(:kid).length, :<=, 255
    assert_operator payload.fetch(:alg).length, :<=, 255
    assert_operator payload.fetch(:iss).length, :<=, 255
    assert_not_includes payload.to_json, raw_jwt
  end

  # Each way an authorization request can be refused maps to a distinct OAuth
  # error, because the client decides whether to retry from that code alone.
  test "a persistence failure answers server_error rather than raising out of the endpoint" do
    coordinator =
      OidcAuthorizeCoordinator.new(params: {}, resource: nil, session_token: nil)
    coordinator.define_singleton_method(:validate_request!) do
      raise Umaxica::Valkey::Unavailable, "authorization code store unavailable"
    end

    result = coordinator.call

    assert_not result.success
    assert_equal "server_error", result.error
  end

  test "an unknown client and an invalid scope answer their own OAuth errors" do
    {
      OidcClientRegistry::ClientNotFound => "unauthorized_client",
      OidcAuthorizeRequestResolver::InvalidScope => "invalid_scope",
      OidcClientRegistry::InvalidRedirectUri => "invalid_request",
      ArgumentError => "invalid_request",
    }.each do |error_class, expected|
      coordinator = OidcAuthorizeCoordinator.new(params: {}, resource: nil, session_token: nil)
      coordinator.define_singleton_method(:validate_request!) { raise error_class, "refused" }

      assert_equal expected, coordinator.call.error, error_class.name
    end
  end
end
