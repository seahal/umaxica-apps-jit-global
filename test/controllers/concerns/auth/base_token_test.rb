# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

module Auth
  class BaseTokenTest < ActiveSupport::TestCase
    test "Token.encode returns nil for nil resource" do
      result = AuthenticationToken.encode(nil, host: "example.com")

      assert_nil result
    end

    test "Token.encode returns nil for blank host" do
      user = clients(:one)
      result = AuthenticationToken.encode(user, host: "")

      assert_nil result
    end

    test "Token.decode returns nil for blank token" do
      result = AuthenticationToken.decode("", host: "example.com", resource_type: "client")

      assert_nil result
    end

    test "Token.decode returns nil for blank host" do
      result = AuthenticationToken.decode("some_token", host: "", resource_type: "client")

      assert_nil result
    end

    test "Token.extract_subject returns subject from payload" do
      payload = { "sub" => 123 }

      assert_equal 123, AuthenticationToken.extract_subject(payload)
    end

    test "Token.extract_resource_type returns the resource type from the domain scope" do
      payload = { "scope" => "authenticated domain:operator read:org" }

      assert_equal "operator", AuthenticationToken.extract_resource_type(payload)
    end

    test "Token.extract_resource_type returns nil for nil payload" do
      assert_nil AuthenticationToken.extract_resource_type(nil)
    end

    test "Token.extract_resource_type returns nil for missing claim" do
      payload = { "sub" => "123" }

      assert_nil AuthenticationToken.extract_resource_type(payload)
    end

    test "Token.resource_type_scope_matches? returns true for matching user" do
      payload = { "scope" => "authenticated domain:client read:self" }

      assert AuthenticationToken.resource_type_scope_matches?(payload, "client")
    end

    test "Token.resource_type_scope_matches? returns true for matching operator" do
      payload = { "scope" => "authenticated domain:operator read:org" }

      assert AuthenticationToken.resource_type_scope_matches?(payload, "operator")
    end

    test "Token.resource_type_scope_matches? returns false for mismatched actor" do
      payload = { "scope" => "authenticated domain:client read:self" }

      assert_not AuthenticationToken.resource_type_scope_matches?(payload, "operator")
    end

    test "Token.resource_type_scope_matches? returns false for nil payload" do
      assert_not AuthenticationToken.resource_type_scope_matches?(nil, "client")
    end

    test "Token.resource_type_scope_matches? returns false for missing claim" do
      payload = { "sub" => "123" }

      assert_not AuthenticationToken.resource_type_scope_matches?(payload, "client")
    end

    test "Token.resource_type_scope_matches? returns false for blank claim" do
      payload = { "scope" => "" }

      assert_not AuthenticationToken.resource_type_scope_matches?(payload, "client")
    end

    test "Token.resource_type_scope_matches? returns false for unrecognized value" do
      payload = { "scope" => "authenticated domain:staff" }

      assert_not AuthenticationToken.resource_type_scope_matches?(payload, "operator")
    end

    test "Token.resource_type_scope_matches? returns false for nil value" do
      payload = { "scope" => nil }

      assert_not AuthenticationToken.resource_type_scope_matches?(payload, "client")
    end

    test "Token.extract_session_id returns sid from payload" do
      payload = { "sid" => "abc123" }

      assert_equal "abc123", AuthenticationToken.extract_session_id(payload)
    end

    test "Token.extract_jti returns jti from payload" do
      payload = { "jti" => "xyz789" }

      assert_equal "xyz789", AuthenticationToken.extract_jti(payload)
    end

    test "Token.encode includes kid header" do
      token = AuthenticationToken.encode(
        clients(:one), host: "example.com", session_public_id: "sid", resource_type: "client",
      )
      _payload, header = JWT.decode(token, nil, false)

      assert_predicate header["kid"], :present?
      assert_equal "at+jwt", header["typ"]
      assert_equal "ES384", header["alg"]
    end

    test "Token roundtrips with an explicit surface issuer and not the legacy auth issuer" do
      token = AuthenticationToken.encode(
        clients(:one),
        host: "log.umaxica.app",
        session_public_id: "sid",
        resource_type: "client",
        jwt_issuer_id: "surface:SIGN_APP",
      )

      # The keyring is never inferred from the host: without the explicit
      # surface keyring the verifier uses the default auth keyring and fails closed.
      assert_nil AuthenticationToken.decode(token, host: "log.umaxica.app", resource_type: "client")

      payload = AuthenticationToken.decode(
        token,
        host: "log.umaxica.app",
        resource_type: "client",
        jwt_issuer_id: "surface:SIGN_APP",
      )

      assert_equal clients(:one).id.to_s, payload["sub"]
    end

    test "Token.decode rejects unknown kid" do
      token = AuthenticationToken.encode(
        clients(:one), host: "example.com", session_public_id: "sid", resource_type: "client",
      )
      payload, header = JWT.decode(token, nil, false)
      tampered = JWT.encode(
        payload, AuthenticationJwtConfiguration.private_key, "ES384",
        { kid: "unknown-kid", typ: header["typ"] },
      )

      assert_nil AuthenticationToken.decode(tampered, host: "example.com", resource_type: "client")
    end

    test "Token.decode rejects alg mismatch" do
      token = AuthenticationToken.encode(
        clients(:one), host: "example.com", session_public_id: "sid", resource_type: "client",
      )
      payload, _header = JWT.decode(token, nil, false)
      active_kid = JitSecurityJwtKeyring.active_kid
      tampered = JWT.encode(payload, "secret_credential", "HS256", { kid: active_kid, typ: "at+jwt" })

      assert_nil AuthenticationToken.decode(tampered, host: "example.com", resource_type: "client")
    end

    test "Token.decode rejects alg none" do
      token = AuthenticationToken.encode(
        clients(:one), host: "example.com", session_public_id: "sid", resource_type: "client",
      )
      payload, _header = JWT.decode(token, nil, false)
      tampered = JWT.encode(
        payload,
        nil,
        "none",
        { kid: JitSecurityJwtKeyring.active_kid, typ: "at+jwt" },
      )

      assert_nil AuthenticationToken.decode(tampered, host: "example.com", resource_type: "client")
    end

    test "Token.decode rejects missing sid claim" do
      token = AuthenticationToken.encode(
        clients(:one), host: "example.com", session_public_id: "sid", resource_type: "client",
      )
      payload, header = JWT.decode(token, nil, false)
      payload.delete("sid")
      tampered = JWT.encode(payload, AuthenticationJwtConfiguration.private_key, "ES384", header)

      assert_nil AuthenticationToken.decode(tampered, host: "example.com", resource_type: "client")
    end

    test "Token.decode rejects missing sub claim" do
      token = AuthenticationToken.encode(
        clients(:one), host: "example.com", session_public_id: "sid", resource_type: "client",
      )
      payload, header = JWT.decode(token, nil, false)
      payload.delete("sub")
      tampered = JWT.encode(payload, AuthenticationJwtConfiguration.private_key, "ES384", header)

      assert_nil AuthenticationToken.decode(tampered, host: "example.com", resource_type: "client")
    end

    test "Token.decode rejects missing JOSE typ" do
      token = AuthenticationToken.encode(
        clients(:one), host: "example.com", session_public_id: "sid", resource_type: "client",
      )
      payload, header = JWT.decode(token, nil, false)
      header.delete("typ")
      tampered = JWT.encode(payload, AuthenticationJwtConfiguration.private_key, "ES384", header)

      assert_nil AuthenticationToken.decode(tampered, host: "example.com", resource_type: "client")
    end

    test "Token.decode rejects numeric sub" do
      token = AuthenticationToken.encode(
        clients(:one), host: "example.com", session_public_id: "sid", resource_type: "client",
      )
      payload, header = JWT.decode(token, nil, false)
      payload["sub"] = Integer(payload["sub"], 10)
      tampered = JWT.encode(payload, AuthenticationJwtConfiguration.private_key, "ES384", header)

      assert_nil AuthenticationToken.decode(tampered, host: "example.com", resource_type: "client")
    end

    test "Token.decode rejects user token for operator resource type" do
      token = AuthenticationToken.encode(
        clients(:one), host: "example.com", session_public_id: "sid", resource_type: "client",
      )

      assert_nil AuthenticationToken.decode(token, host: "example.com", resource_type: "operator")
    end
  end
end
