# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

module Authorization
  class TokenClaimsTest < ActiveSupport::TestCase
    DummyResource = Struct.new(:id)

    def setup_token_claims_payload
      issued_at = Time.zone.parse("2026-02-22 12:00:00")
      payload = AuthorizationTokenClaims.build(
        resource: DummyResource.new(42),
        session_id: "sess_abc",
        resource_type: "client",
        issued_at: issued_at,
        access_token_ttl: 10.minutes,
      )
      [payload, issued_at]
    end

    test "build includes subject and actor claims" do
      payload, _issued_at = setup_token_claims_payload

      assert_equal "42", payload["sub"]
      assert_nil payload["act"]
      assert_includes payload["scope"], "domain:client"
    end

    test "build includes session id claim" do
      payload, _issued_at = setup_token_claims_payload

      assert_equal "sess_abc", payload["sid"]
    end

    test "build includes timestamp claims" do
      payload, issued_at = setup_token_claims_payload

      assert_equal unix_timestamp(issued_at), payload["iat"]
      assert_equal unix_timestamp(issued_at + 10.minutes), payload["exp"]
    end

    test "build includes nbf claim at the issued time" do
      payload, issued_at = setup_token_claims_payload

      assert_equal unix_timestamp(issued_at), payload["nbf"]
    end

    test "build excludes prf claim when preferences not provided" do
      payload, _issued_at = setup_token_claims_payload

      assert_nil payload["prf"], "prf should not be included when no preferences given"
    end

    test "build includes type and issuer claims" do
      payload, _issued_at = setup_token_claims_payload

      assert_nil payload["typ"]
      assert_equal AuthenticationJwtConfiguration.issuer, payload["iss"]
      assert_equal AuthenticationJwtConfiguration.client_id("client"), payload["client_id"]
      assert_kind_of String, payload["scope"]
      assert_nil payload["scp"]
    end

    test "build includes audience and jti claims" do
      payload, _issued_at = setup_token_claims_payload

      assert_equal AuthenticationJwtConfiguration.audiences("client"), payload["aud"]
      assert_predicate payload["jti"], :present?
    end

    test "build prefers oidc identifiers for sid and jti claims" do
      issued_at = Time.zone.parse("2026-02-22 12:00:00")
      payload = AuthorizationTokenClaims.build(
        resource: DummyResource.new(42),
        session_public_id: "token_public_id",
        session_id: "legacy_session_id",
        oidc_sid: "5b0d9bbf-963a-4e30-bc1c-a255ca44585a",
        oidc_jti: "6d0d34c8-f250-4480-92ef-154bcbfc9ec7",
        resource_type: "client",
        issued_at: issued_at,
        access_token_ttl: 10.minutes,
      )

      assert_equal "5b0d9bbf-963a-4e30-bc1c-a255ca44585a", payload["sid"]
      assert_equal "6d0d34c8-f250-4480-92ef-154bcbfc9ec7", payload["jti"]
    end

    test "build uses explicit expires_at when provided" do
      issued_at = Time.zone.parse("2026-02-22 12:00:00")
      expires_at = issued_at + 5.minutes
      payload = AuthorizationTokenClaims.build(
        resource: DummyResource.new(42),
        session_id: "sess_abc",
        resource_type: "client",
        issued_at: issued_at,
        access_token_ttl: 10.minutes,
        expires_at: expires_at,
      )

      assert_equal unix_timestamp(expires_at), payload["exp"]
    end

    test "extractors return nil when payload is nil" do
      assert_nil AuthorizationTokenClaims.subject(nil)
      assert_nil AuthorizationTokenClaims.resource_type(nil)
      assert_nil AuthorizationTokenClaims.session_id(nil)
      assert_nil AuthorizationTokenClaims.jti(nil)
    end

    test "build does not include preference claim" do
      issued_at = Time.zone.parse("2026-02-22 12:00:00")
      payload = AuthorizationTokenClaims.build(
        resource: DummyResource.new(42),
        session_id: "sess_abc",
        resource_type: "client",
        issued_at: issued_at,
        access_token_ttl: 10.minutes,
      )

      assert_nil payload["prf"], "auth JWT should not contain preference data when nil"
    end

    test "build includes cnf.jkt when dpop_jkt provided" do
      issued_at = Time.zone.parse("2026-02-22 12:00:00")
      payload = AuthorizationTokenClaims.build(
        resource: DummyResource.new(42),
        session_id: "sess_abc",
        resource_type: "client",
        issued_at: issued_at,
        access_token_ttl: 10.minutes,
        dpop_jkt: "thumb456",
      )

      assert_equal({ "jkt" => "thumb456" }, payload["cnf"])
    end

    test "build backward compatible with session_public_id parameter" do
      issued_at = Time.zone.parse("2026-02-22 12:00:00")
      payload = AuthorizationTokenClaims.build(
        resource: DummyResource.new(42),
        session_public_id: "legacy_sid",
        resource_type: "client",
        issued_at: issued_at,
        access_token_ttl: 10.minutes,
      )

      assert_equal "legacy_sid", payload["sid"]
    end

    private

    def unix_timestamp(value)
      value.to_i
    end
  end
end
