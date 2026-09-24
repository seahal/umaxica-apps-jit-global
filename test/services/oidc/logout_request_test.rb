# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class OidcLogoutRequestTest < ActiveSupport::TestCase
  test "round trips signed logout request" do
    token = OidcLogoutRequest.issue(client_id: "core-app", ri: "jp")

    payload = OidcLogoutRequest.verify(token)

    assert_equal "core-app", payload[:client_id]
    assert_equal "jp", payload[:ri]
  end

  test "rejects tampered logout request" do
    token = OidcLogoutRequest.issue(client_id: "core-app", ri: "jp")

    assert_nil OidcLogoutRequest.verify("#{token}x")
  end

  test "normalizes unsupported region to default" do
    token = OidcLogoutRequest.issue(client_id: "core-app", ri: "evil")

    assert_equal "jp", OidcLogoutRequest.verify(token)[:ri]
  end

  test "returns nil on the second verify of the same token (replay protection)" do
    token = OidcLogoutRequest.issue(client_id: "core-app", ri: "jp")

    first = OidcLogoutRequest.verify(token)
    second = OidcLogoutRequest.verify(token)

    assert_not_nil first
    assert_equal "core-app", first[:client_id]
    assert_nil second, "Re-presenting the same signed logout request must be rejected"
  end

  test "includes a non-empty jti claim on every issued token" do
    token_a = OidcLogoutRequest.issue(client_id: "core-app", ri: "jp")
    token_b = OidcLogoutRequest.issue(client_id: "core-app", ri: "jp")

    payload_a = OidcLogoutRequest.verify(token_a)
    payload_b = OidcLogoutRequest.verify(token_b)

    assert_predicate payload_a[:jti], :present?
    assert_predicate payload_b[:jti], :present?
    assert_not_equal payload_a[:jti], payload_b[:jti]
  end

  test "stores a digest instead of raw logout request jti" do
    token = OidcLogoutRequest.issue(client_id: "core-app", ri: "jp")
    payload = OidcLogoutRequest.verify(token)

    record = SecurityConsumedJti.find_by!(
      purpose: SecurityConsumedJti::PURPOSES.fetch(:oidc_logout_request),
      issuer: "core-app",
      jti_digest: SecurityConsumedJti.digest_jti(payload.fetch(:jti)),
    )

    assert_not_equal payload.fetch(:jti), record.jti_digest
    assert_operator record.expires_at, :>, Time.current
  end

  test "does not use Rails cache for logout request replay tracking" do
    cache = Class.new do
      def exist?(*)
        raise StandardError, "Rails.cache must not track logout request replay"
      end

      def write(*)
        raise StandardError, "Rails.cache must not track logout request replay"
      end
    end.new
    token = OidcLogoutRequest.issue(client_id: "core-app", ri: "jp")

    Rails.stub(:cache, cache) do
      assert_not_nil OidcLogoutRequest.verify(token)
    end
  end
end
