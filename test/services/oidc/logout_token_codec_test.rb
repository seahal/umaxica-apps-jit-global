# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class OidcLogoutTokenCodecTest < ActiveSupport::TestCase
  test "encodes and verifies a back-channel logout token" do
    with_oidc_key("ACME_APP") do
      token = OidcLogoutTokenCodec.encode(
        client_id: "sign-rp",
        resource_type: "client",
        subject: "subject-1",
        sid: SecureRandom.uuid,
      )

      result = OidcLogoutTokenCodec.decode(
        logout_token: token,
        client_id: "sign-rp",
        resource_type: "client",
      )

      assert_predicate result, :success?
      assert_equal OidcLogoutTokenCodec::TOKEN_TYPE, result.payload.fetch("typ")
      assert result.payload.fetch("events").key?(OidcLogoutTokenCodec::EVENT_CLAIM)
      assert_operator result.payload.fetch("exp"), :>, result.payload.fetch("iat")
      assert_match OidcLogoutTokenCodec::UUID_PATTERN, result.payload.fetch("sid")
      assert_not result.payload.key?("nonce")
    end
  end

  test "encodes and verifies a back-channel logout token without subject" do
    with_oidc_key("ACME_APP") do
      token = OidcLogoutTokenCodec.encode(
        client_id: "sign-rp",
        resource_type: "client",
        subject: nil,
        sid: SecureRandom.uuid,
      )

      result = OidcLogoutTokenCodec.decode(
        logout_token: token,
        client_id: "sign-rp",
        resource_type: "client",
      )

      assert_predicate result, :success?
      assert_not result.payload.key?("sub")
      assert_match OidcLogoutTokenCodec::UUID_PATTERN, result.payload.fetch("sid")
    end
  end

  test "rejects replayed logout token jti" do
    with_oidc_key("ACME_APP") do
      token = OidcLogoutTokenCodec.encode(
        client_id: "sign-rp",
        resource_type: "client",
        subject: "subject-1",
        sid: SecureRandom.uuid,
      )

      assert_predicate OidcLogoutTokenCodec.decode(
        logout_token: token,
        client_id: "sign-rp",
        resource_type: "client",
      ), :success?
      assert_not OidcLogoutTokenCodec.decode(
        logout_token: token,
        client_id: "sign-rp",
        resource_type: "client",
      ).success?
    end
  end

  test "stores a digest instead of raw logout token jti" do
    with_oidc_key("ACME_APP") do
      token = OidcLogoutTokenCodec.encode(
        client_id: "sign-rp",
        resource_type: "client",
        subject: "subject-1",
        sid: SecureRandom.uuid,
      )

      result = OidcLogoutTokenCodec.decode(
        logout_token: token,
        client_id: "sign-rp",
        resource_type: "client",
      )

      record = SecurityConsumedJti.find_by!(
        purpose: SecurityConsumedJti::PURPOSES.fetch(:oidc_logout_token),
        issuer: OidcIssuer.for_resource_type("client"),
        jti_digest: SecurityConsumedJti.digest_jti(result.payload.fetch("jti")),
      )

      assert_not_equal result.payload.fetch("jti"), record.jti_digest
      assert_operator record.expires_at, :>, Time.current
    end
  end

  test "does not use Rails cache for logout token replay tracking" do
    with_oidc_key("ACME_APP") do
      token = OidcLogoutTokenCodec.encode(
        client_id: "sign-rp",
        resource_type: "client",
        subject: "subject-1",
        sid: SecureRandom.uuid,
      )
      cache = Class.new do
        def exist?(*)
          raise StandardError, "Rails.cache must not track logout token replay"
        end

        def write(*)
          raise StandardError, "Rails.cache must not track logout token replay"
        end
      end.new

      Rails.stub(:cache, cache) do
        assert_predicate OidcLogoutTokenCodec.decode(
          logout_token: token,
          client_id: "sign-rp",
          resource_type: "client",
        ), :success?
      end
    end
  end

  test "rejects an audience mismatch" do
    with_oidc_key("ACME_APP") do
      token = OidcLogoutTokenCodec.encode(
        client_id: "sign-rp",
        resource_type: "client",
        subject: "subject-1",
        sid: SecureRandom.uuid,
      )

      result = OidcLogoutTokenCodec.decode(
        logout_token: token,
        client_id: "core-next-rp",
        resource_type: "client",
      )

      assert_not_predicate result, :success?
    end
  end

  test "rejects missing sid at encode" do
    with_oidc_key("ACME_APP") do
      assert_raises(ArgumentError) do
        OidcLogoutTokenCodec.encode(
          client_id: "sign-rp",
          resource_type: "client",
          subject: nil,
          sid: nil,
        )
      end
    end
  end

  test "rejects blank sid at encode" do
    with_oidc_key("ACME_APP") do
      assert_raises(ArgumentError) do
        OidcLogoutTokenCodec.encode(
          client_id: "sign-rp",
          resource_type: "client",
          subject: "subject-1",
          sid: "   ",
        )
      end
    end
  end

  test "rejects non-UUID sid at encode" do
    with_oidc_key("ACME_APP") do
      assert_raises(ArgumentError) do
        OidcLogoutTokenCodec.encode(
          client_id: "sign-rp",
          resource_type: "client",
          subject: "subject-1",
          sid: "not-a-uuid",
        )
      end
    end
  end

  test "rejects sub-only token at decode" do
    with_oidc_key("ACME_APP") do
      payload = base_logout_payload
      payload.delete("sid")
      token = forge_logout_token(resource_type: "client", payload: payload)

      assert_not_predicate decode_logout_token(token), :success?
    end
  end

  test "rejects missing sid at decode" do
    with_oidc_key("ACME_APP") do
      payload = base_logout_payload
      payload.delete("sid")
      payload.delete("sub")
      token = forge_logout_token(resource_type: "client", payload: payload)

      assert_not_predicate decode_logout_token(token), :success?
    end
  end

  test "rejects non-UUID sid at decode" do
    with_oidc_key("ACME_APP") do
      token = forge_logout_token(resource_type: "client", payload: base_logout_payload("sid" => "not-a-uuid"))

      assert_not_predicate decode_logout_token(token), :success?
    end
  end

  test "rejects missing iat at decode" do
    with_oidc_key("ACME_APP") do
      payload = base_logout_payload
      payload.delete("iat")
      token = forge_logout_token(resource_type: "client", payload: payload)

      assert_not_predicate decode_logout_token(token), :success?
    end
  end

  test "rejects invalid iat at decode" do
    with_oidc_key("ACME_APP") do |key, kid|
      payload = base_logout_payload("iat" => "not-an-int")
      token = JWT::Token.new(
        payload: payload,
        header: {
          "kid" => kid,
          "typ" => OidcLogoutTokenCodec::TOKEN_TYPE,
        },
      ).tap { |jwt| jwt.sign!(key: key, algorithm: OidcLogoutTokenCodec::JWT_ALGORITHM) }.jwt

      assert_not_predicate decode_logout_token(token), :success?
    end
  end

  test "rejects missing exp at decode" do
    with_oidc_key("ACME_APP") do
      payload = base_logout_payload
      payload.delete("exp")
      token = forge_logout_token(resource_type: "client", payload: payload)

      assert_not_predicate decode_logout_token(token), :success?
    end
  end

  test "rejects expired token at decode" do
    with_oidc_key("ACME_APP") do
      token = forge_logout_token(resource_type: "client", payload: base_logout_payload("exp" => 1.hour.ago.to_i))

      assert_not_predicate decode_logout_token(token), :success?
    end
  end

  test "rejects nonce present" do
    with_oidc_key("ACME_APP") do
      token = forge_logout_token(resource_type: "client", payload: base_logout_payload("nonce" => SecureRandom.hex(8)))

      assert_not_predicate decode_logout_token(token), :success?
    end
  end

  test "rejects wrong events claim" do
    with_oidc_key("ACME_APP") do
      token = forge_logout_token(
        resource_type: "client",
        payload: base_logout_payload("events" => { "http://other" => {} }),
      )

      assert_not_predicate decode_logout_token(token), :success?
    end
  end

  test "rejects missing events claim" do
    with_oidc_key("ACME_APP") do
      payload = base_logout_payload
      payload.delete("events")
      token = forge_logout_token(resource_type: "client", payload: payload)

      assert_not_predicate decode_logout_token(token), :success?
    end
  end

  test "rejects wrong issuer at decode" do
    with_oidc_key("ACME_APP") do
      token = forge_logout_token(
        resource_type: "client",
        payload: base_logout_payload("iss" => OidcIssuer.for_resource_type("visitor")),
      )

      assert_not_predicate decode_logout_token(token), :success?
    end
  end

  private

  def with_oidc_key(namespace)
    key = OpenSSL::PKey::EC.generate("secp384r1")
    kid = "#{namespace.downcase.tr("_", "-")}-oidc-test"
    env = {
      "OIDC_CLIENT_#{namespace}_ACTIVE_KID" => kid,
      "OIDC_CLIENT_#{namespace}_PRIVATE_KEY" => Base64.strict_encode64(key.to_der),
    }
    previous = JitSecurityJwtRegistry.instance_variable_get(:@issuers)

    with_env(env) do
      JitSecurityJwtRegistry.reload!
      yield key, kid
    ensure
      JitSecurityJwtRegistry.instance_variable_set(:@issuers, previous)
    end
  end

  def with_env(values)
    previous = {}
    values.each do |key, value|
      previous[key] = ENV[key]
      value.nil? ? ENV.delete(key) : ENV[key] = value
    end
    yield
  ensure
    previous.each do |key, value|
      value.nil? ? ENV.delete(key) : ENV[key] = value
    end
  end

  def base_logout_payload(overrides = {})
    {
      "iss" => OidcIssuer.for_resource_type("client"),
      "aud" => "sign-rp",
      "iat" => Time.current.to_i,
      "exp" => 2.minutes.from_now.to_i,
      "jti" => SecureRandom.uuid,
      "typ" => OidcLogoutTokenCodec::TOKEN_TYPE,
      "events" => { OidcLogoutTokenCodec::EVENT_CLAIM => {} },
      "sub" => "subject-1",
      "sid" => SecureRandom.uuid,
    }.merge(overrides)
  end

  def forge_logout_token(resource_type:, payload:)
    JitSecurityJwtKeyring.encode(
      payload,
      typ: payload["typ"].presence || OidcLogoutTokenCodec::TOKEN_TYPE,
      issuer_id: OidcIssuer.jwt_issuer_id_for_resource_type(resource_type),
    )
  end

  def decode_logout_token(token)
    OidcLogoutTokenCodec.decode(
      logout_token: token,
      client_id: "sign-rp",
      resource_type: "client",
    )
  end
end
