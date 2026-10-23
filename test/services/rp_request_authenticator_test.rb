# frozen_string_literal: true

require "test_helper"

class RpRequestAuthenticatorTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  ISSUER = "https://www.umaxica.app"

  setup do
    @cell = RpCellBinding.fetch("rp_core_app")
    @key = OpenSSL::PKey::EC.generate("secp384r1")
    @enrollment = RpCallbackCommitter.call(
      cell: @cell, issuer: ISSUER, subject: "subject-a", sid: "sid-1",
      absolute_expires_at: 1.hour.from_now,
    )
  end

  test "a verified Access JWT bound to a live local session authenticates as the local principal" do
    result = authenticate

    assert_predicate result, :authenticated?
    assert_equal @enrollment.principal, result.principal
    assert_equal @enrollment.session, result.session
  end

  test "either credential missing is a missing authentication" do
    assert_equal :missing, authenticate(token: nil).status
    assert_equal :missing, authenticate(session_id: "").status
  end

  test "a local session alone never authenticates: the Access JWT must verify" do
    forged = JWT.encode(
      payload, OpenSSL::PKey::EC.generate("secp384r1"), "ES384",
      { "kid" => "k1", "alg" => "ES384", "typ" => "at+jwt" },
    )

    assert_equal :invalid, authenticate(token: forged).status
  end

  test "the Access JWT must name the session's sid and subject" do
    assert_equal :invalid, authenticate(token: token(payload.merge("sid" => "sid-other"))).status
    assert_equal :invalid, authenticate(token: token(payload.merge("sub" => "subject-b"))).status
  end

  test "a revoked OP binding, a revoked session or an expired session stops authenticating" do
    anchor = RpCoreAppOpSessionBinding.find(@enrollment.session.op_session_binding_id)
    anchor.update_columns(revoked_at: Time.current)

    assert_equal :invalid, authenticate.status

    anchor.update_columns(revoked_at: nil)
    @enrollment.session.update_columns(revoked_at: Time.current)

    assert_equal :invalid, authenticate.status

    @enrollment.session.update_columns(revoked_at: nil, absolute_expires_at: 1.second.ago)

    assert_equal :invalid, authenticate.status
  end

  test "a disabled local principal stops authenticating" do
    @enrollment.principal.update_columns(disabled_at: Time.current)

    assert_equal :invalid, authenticate.status
  end

  test "local expiry uses the fresh writer clock despite a slower application clock and a reading caller" do
    base = Time.current.change(usec: 0)
    @enrollment.session.update!(absolute_expires_at: base + 30)
    access = JWT.encode(
      { "iss" => ISSUER,
        "aud" => [@cell.client_id],
        "exp" => base.to_i + 300,
        "nbf" => base.to_i - 5,
        "iat" => base.to_i - 5,
        "sub" => "subject-a",
        "sid" => "sid-1",
        "client_id" => @cell.client_id,
        "jti" => "writer-expiry",
        "scope" => "openid",
        "authn_ctx" => "normal", },
      @key, "ES384", { "kid" => "k1", "typ" => "at+jwt" },
    )
    keys = OidcOpJwksClient.new(
      jwks_uri: "#{ISSUER}/.well-known/jwks.json",
      fetcher: -> { { "keys" => [JitSecurityJwtJwk.export_public(@key, kid: "k1")] } },
    )
    [-Rational(1, 1_000_000), 0, Rational(1, 1_000_000)].each do |offset|
      RpCoreAppRecord.stub(:database_now, base + 30 + offset) do
        RpCoreAppRecord.connected_to(role: :reading) do
          result = RpRequestAuthenticator.call(
            cell: @cell, access_token: access, local_session_id: @enrollment.session.public_id,
            issuer: ISSUER, jwks_client: keys,
          )

          assert_equal offset.negative? ? :authenticated : :invalid, result.status
        end
      end
    end
  end

  private

  def authenticate(token: token(payload), session_id: @enrollment.session.public_id)
    RpRequestAuthenticator.call(
      cell: @cell, access_token: token, local_session_id: session_id, issuer: ISSUER,
      jwks_client: OidcOpJwksClient.new(
        jwks_uri: "https://www.umaxica.app/.well-known/jwks.json",
        fetcher: -> { { "keys" => [JitSecurityJwtJwk.export_public(@key, kid: "k1")] } },
        clock: -> { Time.current },
      ),
    )
  end

  def token(claims)
    JWT.encode(claims, @key, "ES384", { "kid" => "k1", "alg" => "ES384", "typ" => "at+jwt" })
  end

  def payload
    now = Time.current.to_i
    {
      "iss" => ISSUER,
      "aud" => ["core-app-jp"],
      "exp" => now + 300,
      "nbf" => now - 5,
      "iat" => now - 5,
      "sub" => "subject-a",
      "sid" => "sid-1",
      "client_id" => "core-app-jp",
      "jti" => "jti-1",
      "scope" => "openid",
      "authn_ctx" => "normal",
    }
  end
end
