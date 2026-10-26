# frozen_string_literal: true

require "test_helper"

class RpRefreshCommitterTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  ISSUER = "https://www.umaxica.app"
  Outcome = OidcOpTokenClient::Result

  setup do
    @cell = RpCellBinding.fetch("rp_core_app")
    @key = OpenSSL::PKey::EC.generate("secp384r1")
    @session = RpCallbackCommitter.call(
      cell: @cell, issuer: ISSUER, subject: "subject-a", sid: "sid-1",
      absolute_expires_at: 1.hour.from_now,
    ).session
  end

  test "a successful Refresh installs exactly one new generation" do
    result = refresh(token: success)

    assert_predicate result, :installed?
    assert_equal 1, @session.reload.installed_generation
    assert_equal Digest::SHA256.hexdigest("jti-1"), @session.current_access_jti_digest
  end

  test "only the standard refresh grant parameters are sent to the OP" do
    sent = nil
    refresh(
      token: ->(**kwargs) {
        sent = kwargs
        success
      },
    )

    assert_equal %i(client_id deadline refresh_token token_url), sent.keys.sort
    assert_equal "refresh-plain", sent.fetch(:refresh_token)
  end

  test "a definitive refusal installs nothing" do
    assert_equal :refused,
                 refresh(token: Outcome.new(outcome: :refused, token_response: nil, error: "invalid_grant")).outcome
    assert_equal 0, @session.reload.installed_generation
  end

  test "a Refresh overtaken by another installed generation is superseded" do
    token =
      lambda do |**|
        @session.update_columns(installed_generation: 5)
        success
      end

    assert_equal :superseded, refresh(token:).outcome
    assert_equal 5, @session.reload.installed_generation
  end

  test "a session revoked during dispatch never installs the returned tokens" do
    token =
      lambda do |**|
        RpCoreAppOpSessionBinding.where(id: @session.op_session_binding_id).update_all(revoked_at: Time.current)
        success
      end

    assert_equal :revoked, refresh(token:).outcome
    assert_equal 0, @session.reload.installed_generation
  end

  test "a revoked session does not dispatch at all" do
    @session.update_columns(revoked_at: Time.current)

    assert_equal :revoked, refresh(token: ->(**) { flunk("must not dispatch") }).outcome
  end

  test "a returned Access JWT for another sid is refused" do
    other = Outcome.new(
      outcome: :success, token_response: { access_token: jwt(payload.merge("sid" => "sid-2")) },
      error: nil,
    )

    assert_equal :refused, refresh(token: other).outcome
  end

  test "Refresh refuses signed responses for another subject" do
    jwks = OidcOpJwksClient.new(
      jwks_uri: "#{ISSUER}/.well-known/jwks.json",
      fetcher: -> { { "keys" => [JitSecurityJwtJwk.export_public(@key, kid: "k1")] } },
    )
    ["other-subject"].each do |subject|
      session = RpCallbackCommitter.call(
        cell: @cell, issuer: ISSUER, subject: "subject-a", sid: "binding-#{subject}",
        absolute_expires_at: 1.hour.from_now,
      ).session
      now = Time.current.to_i
      token = JWT.encode(
        { "iss" => ISSUER,
          "aud" => ["core-app-jp"],
          "exp" => now + 300,
          "nbf" => now - 5,
          "iat" => now - 5,
          "sub" => subject,
          "sid" => "binding-#{subject}",
          "client_id" => "core-app-jp",
          "jti" => "wrong-binding",
          "scope" => "openid",
          "authn_ctx" => "normal", },
        @key, "ES384", { "kid" => "k1", "typ" => "at+jwt" },
      )
      response = Outcome.new(
        outcome: :success, token_response: { access_token: token, refresh_token: "next" },
        error: nil,
      )
      OidcOpTokenClient.stub(:refresh, response) do
        result = RpRefreshCommitter.call(
          cell: @cell, local_session_id: session.public_id, refresh_token: "refresh-plain", issuer: ISSUER,
          jwks_client: jwks, token_url: "#{ISSUER}/oauth/token",
        )

        assert_equal :refused, result.outcome, subject
      end
      assert_equal 0, session.reload.installed_generation
      assert_nil session.current_access_jti_digest
    end
  end

  test "a revoked binding or disabled principal prevents Refresh before dispatch" do
    [:binding, :principal].each do |cohort|
      session = RpCallbackCommitter.call(
        cell: @cell, issuer: ISSUER, subject: "ended-#{cohort}", sid: "ended-#{cohort}",
        absolute_expires_at: 1.hour.from_now,
      ).session
      anchor = RpCoreAppOpSessionBinding.includes(identity_binding: :principal).find(session.op_session_binding_id)
      if cohort == :binding
        anchor.revoke!
      else
        anchor.identity_binding.principal.update!(disabled_at: Time.current)
      end
      OidcOpTokenClient.stub(:refresh, ->(**) { flunk("ended local authority must not dispatch") }) do
        result = RpRefreshCommitter.call(
          cell: @cell, local_session_id: session.public_id, refresh_token: "refresh-plain", issuer: ISSUER,
          jwks_client: nil, token_url: "#{ISSUER}/oauth/token",
        )

        assert_equal :revoked, result.outcome
      end
    end
  end

  test "missing unknown and database primary key session locators never dispatch Refresh" do
    [nil, "", "unknown-session", @session.id.to_s].each do |locator|
      OidcOpTokenClient.stub(:refresh, ->(**) { flunk("only the opaque enrolled session can refresh") }) do
        result = RpRefreshCommitter.call(
          cell: @cell, local_session_id: locator, refresh_token: "refresh-plain", issuer: ISSUER,
          jwks_client: nil, token_url: "#{ISSUER}/oauth/token",
        )

        assert_equal :revoked, result.outcome
      end
    end
  end

  test "a caller in a reading role still checks the session on the cell writer" do
    response = Outcome.new(outcome: :refused, token_response: nil, error: "invalid_grant")
    OidcOpTokenClient.stub(:refresh, response) do
      RpCoreAppRecord.connected_to(role: :reading) do
        result = RpRefreshCommitter.call(
          cell: @cell, local_session_id: @session.public_id, refresh_token: "refresh-plain", issuer: ISSUER,
          jwks_client: nil, token_url: "#{ISSUER}/oauth/token",
        )

        assert_equal :refused, result.outcome
      end
    end
  end

  test "D-25: an indeterminate rotation is dispatched once and never resent, so the browser needs a new Code Flow" do
    dispatched = 0
    token =
      lambda do |**|
        dispatched += 1
        Outcome.new(outcome: :indeterminate, token_response: nil, error: "timeout")
      end

    assert_equal :refused, refresh(token:).outcome
    assert_equal 1, dispatched
    assert_equal 0, @session.reload.installed_generation
  end

  test "dependency and invalid remote outcomes keep the session generation for a later retry" do
    %i(dependency invalid_remote).each do |outcome|
      result = refresh(token: Outcome.new(outcome:, token_response: nil, error: "x"))

      assert_equal :dependency, result.outcome, outcome
    end
    assert_equal 0, @session.reload.installed_generation
  end

  test "an unverifiable successful OP response is refused because the presented credential is consumed" do
    unverifiable = Outcome.new(outcome: :success, token_response: { access_token: "not-a-jwt" }, error: nil)

    assert_equal :refused, refresh(token: unverifiable).outcome
    assert_equal 0, @session.reload.installed_generation
  end

  private

  def refresh(token:)
    OidcOpTokenClient.stub(:refresh, token) do
      RpRefreshCommitter.call(
        cell: @cell, local_session_id: @session.public_id, refresh_token: "refresh-plain",
        issuer: ISSUER, jwks_client: jwks, token_url: "#{ISSUER}/oauth/token",
      )
    end
  end

  def success
    Outcome.new(outcome: :success, token_response: { access_token: jwt(payload), refresh_token: "next" }, error: nil)
  end

  def jwks
    OidcOpJwksClient.new(
      jwks_uri: "#{ISSUER}/.well-known/jwks.json",
      fetcher: -> { { "keys" => [JitSecurityJwtJwk.export_public(@key, kid: "k1")] } },
      clock: -> { Time.current },
    )
  end

  def jwt(claims)
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
