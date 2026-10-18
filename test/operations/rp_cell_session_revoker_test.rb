# frozen_string_literal: true

require "test_helper"

class RpCellSessionRevokerTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  ISSUER = "https://www.umaxica.app"

  setup do
    @cell = RpCellBinding.fetch("rp_core_app")
    @key = OpenSSL::PKey::EC.generate("secp384r1")
  end

  test "a verified logout revokes the sid's binding and its live local session in one commit" do
    session = enroll("sid-1")

    assert_equal :revoked, revoke(payload("sid-1"))
    assert_not_nil RpCoreAppOpSessionBinding.find_by!(sid: "sid-1").revoked_at
    assert_not_nil session.reload.revoked_at
    assert_equal 1, RpCoreAppEventReceipt.count
  end

  test "a duplicate delivery of the same event is a success without a second receipt" do
    enroll("sid-1")
    revoke(payload("sid-1"))

    assert_equal :duplicate, revoke(payload("sid-1"))
    assert_equal 1, RpCoreAppEventReceipt.count
  end

  test "a logout for a never-seen sid leaves a tombstone that a late callback cannot reopen" do
    assert_equal :revoked, revoke(payload("sid-unknown"))
    late = RpCallbackCommitter.call(
      cell: @cell, issuer: ISSUER, subject: "subject-a", sid: "sid-unknown",
      absolute_expires_at: 1.hour.from_now, contract_epoch: 1,
    )

    assert_equal :revoked, late.outcome
  end

  test "the logout token verifier accepts only a strict back-channel logout token" do
    assert_predicate verify(token(payload("sid-1"))), :success?
    assert_not_predicate verify(token(payload("sid-1").merge("nonce" => "n"))), :success?
    assert_not_predicate verify(token(payload("sid-1").except("events"))), :success?
    assert_not_predicate verify(token(payload("sid-1").merge("aud" => ["warp-app-jp"]))), :success?
    assert_not_predicate verify(token(payload("sid-1").merge("iss" => "https://evil.test"))), :success?
    assert_not_predicate verify(token(payload("sid-1"), typ: "JWT")), :success?
    assert_not_predicate verify(token(payload("sid-1"), key: OpenSSL::PKey::EC.generate("secp384r1"))), :success?
    assert_not_predicate verify(""), :success?
  end

  test "logout selects the cell writer when entered from a reading role" do
    RpCoreAppRecord.connected_to(role: :reading) do
      assert_equal :revoked, RpCellSessionRevoker.call(
        cell: @cell, payload: { "iss" => ISSUER,
                                "sid" => "writer-sid",
                                "jti" => "writer-jti",
                                "exp" => 5.minutes.from_now.to_i, },
      )
    end

    assert_not_nil RpCoreAppOpSessionBinding.find_by!(sid: "writer-sid").revoked_at
    assert_equal 1, RpCoreAppEventReceipt.count
  end

  private

  def enroll(sid)
    RpCallbackCommitter.call(
      cell: @cell, issuer: ISSUER, subject: "subject-a", sid:, absolute_expires_at: 1.hour.from_now, contract_epoch: 1,
    ).session
  end

  def revoke(claims)
    RpCellSessionRevoker.call(cell: @cell, payload: claims)
  end

  def verify(logout_token)
    OidcOpLogoutTokenVerifier.new(
      logout_token:, client_id: "core-app-jp", issuer: ISSUER,
      jwks_client: OidcOpJwksClient.new(
        jwks_uri: "#{ISSUER}/.well-known/jwks.json",
        fetcher: -> { { "keys" => [JitSecurityJwtJwk.export_public(@key, kid: "k1")] } },
        clock: -> { Time.current },
      ),
    ).call
  end

  def token(claims, key: @key, typ: "logout+jwt")
    JWT.encode(claims, key, "ES384", { "kid" => "k1", "alg" => "ES384", "typ" => typ })
  end

  def payload(sid)
    now = Time.current.to_i
    {
      "iss" => ISSUER,
      "aud" => ["core-app-jp"],
      "iat" => now,
      "exp" => now + 120,
      "jti" => "jti-#{sid}",
      "sid" => sid,
      "events" => { OidcOpLogoutTokenVerifier::EVENT => {} },
    }
  end
end
