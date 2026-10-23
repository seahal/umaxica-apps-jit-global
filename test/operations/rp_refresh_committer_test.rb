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

  test "a successful Refresh installs exactly one new generation and records the attempt" do
    result = refresh(token: success)

    assert_predicate result, :installed?
    assert_equal 1, @session.reload.installed_generation
    assert_equal Digest::SHA256.hexdigest("jti-1"), @session.current_access_jti_digest
    attempt = RpCoreAppRefreshAttempt.sole

    assert_equal [0, true], [attempt.expected_installed_generation, attempt.installed_at.present?]
  end

  test "the attempt reference is sent to the OP and the credential is never stored" do
    sent = nil
    refresh(
      token: ->(**kwargs) {
        sent = kwargs
        success
      },
    )

    attempt = RpCoreAppRefreshAttempt.sole

    assert_equal attempt.public_id, sent.fetch(:attempt_ref)
    assert_not_includes attempt.input_hmac, "refresh-plain"
  end

  test "a definitive refusal installs nothing" do
    assert_equal :refused,
                 refresh(token: Outcome.new(outcome: :refused, token_response: nil, error: "invalid_grant")).outcome
    assert_equal 0, @session.reload.installed_generation
  end

  test "an indeterminate rotation is recovered once through the delivery query for the same attempt" do
    queried = nil
    query =
      lambda do |**kwargs|
        queried = kwargs
        success
      end
    result = refresh(token: Outcome.new(outcome: :indeterminate, token_response: nil, error: "timeout"), query:)

    assert_predicate result, :installed?
    assert_equal RpCoreAppRefreshAttempt.sole.public_id, queried.fetch(:attempt_ref)
    assert_predicate RpCoreAppRefreshAttempt.sole.uncertain_at, :present?
  end

  test "an indeterminate rotation whose query is refused requires a new Code Flow" do
    refused = Outcome.new(outcome: :refused, token_response: nil, error: "invalid_grant")
    result = refresh(token: Outcome.new(outcome: :indeterminate, token_response: nil, error: "timeout"), query: refused)

    assert_equal :refused, result.outcome
  end

  test "an attempt overtaken by another installed generation is superseded" do
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
          query_url: "#{ISSUER}/oauth/refresh-deliveries/query",
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
          query_url: "#{ISSUER}/oauth/refresh-deliveries/query",
        )

        assert_equal :revoked, result.outcome
      end
      assert_equal 0, RpCoreAppRefreshAttempt.count
    end
  end

  test "missing unknown and database primary key session locators never dispatch Refresh" do
    [nil, "", "unknown-session", @session.id.to_s].each do |locator|
      OidcOpTokenClient.stub(:refresh, ->(**) { flunk("only the opaque enrolled session can refresh") }) do
        result = RpRefreshCommitter.call(
          cell: @cell, local_session_id: locator, refresh_token: "refresh-plain", issuer: ISSUER,
          jwks_client: nil, token_url: "#{ISSUER}/oauth/token",
          query_url: "#{ISSUER}/oauth/refresh-deliveries/query",
        )

        assert_equal :revoked, result.outcome
      end
      assert_equal 0, RpCoreAppRefreshAttempt.count
    end
  end

  test "a caller in a reading role still reserves the Refresh attempt on the cell writer" do
    response = Outcome.new(outcome: :refused, token_response: nil, error: "invalid_grant")
    OidcOpTokenClient.stub(:refresh, response) do
      RpCoreAppRecord.connected_to(role: :reading) do
        result = RpRefreshCommitter.call(
          cell: @cell, local_session_id: @session.public_id, refresh_token: "refresh-plain", issuer: ISSUER,
          jwks_client: nil, token_url: "#{ISSUER}/oauth/token",
          query_url: "#{ISSUER}/oauth/refresh-deliveries/query",
        )

        assert_equal :refused, result.outcome
      end
    end

    assert_equal 1, RpCoreAppRefreshAttempt.count
  end

  test "an unresolved delivery failure resumes the same query without resending the predecessor" do
    now = Time.current.to_i
    token = JWT.encode(
      { "iss" => ISSUER,
        "aud" => ["core-app-jp"],
        "exp" => now + 300,
        "nbf" => now - 5,
        "iat" => now - 5,
        "sub" => "subject-a",
        "sid" => "sid-1",
        "client_id" => "core-app-jp",
        "jti" => "recovered",
        "scope" => "openid",
        "authn_ctx" => "normal", },
      @key, "ES384", { "kid" => "k1", "typ" => "at+jwt" },
    )
    jwks = OidcOpJwksClient.new(
      jwks_uri: "#{ISSUER}/.well-known/jwks.json",
      fetcher: -> { { "keys" => [JitSecurityJwtJwk.export_public(@key, kid: "k1")] } },
    )
    arguments = {
      cell: @cell,
      local_session_id: @session.public_id,
      refresh_token: "refresh-plain",
      issuer: ISSUER,

      jwks_client: jwks,
      token_url: "#{ISSUER}/oauth/token",
      query_url: "#{ISSUER}/oauth/refresh-deliveries/query",
    }
    timeout = Outcome.new(outcome: :indeterminate, token_response: nil, error: "timeout")
    dependency = Outcome.new(outcome: :dependency, token_response: nil, error: "unavailable")
    OidcOpTokenClient.stub(:refresh, timeout) do
      OidcOpTokenClient.stub(:query_delivery, dependency) do
        assert_equal :dependency, RpRefreshCommitter.call(**arguments).outcome
      end
    end
    attempt = RpCoreAppRefreshAttempt.sole
    response = Outcome.new(outcome: :success, token_response: { access_token: token }, error: nil)
    queried_attempt = nil
    OidcOpTokenClient.stub(:refresh, ->(**) { flunk("the uncertain predecessor must never be rotated again") }) do
      OidcOpTokenClient.stub(
        :query_delivery, ->(**params) {
                           queried_attempt = params.fetch(:attempt_ref)
                           response
                         },
      ) do
        assert_predicate RpRefreshCommitter.call(**arguments), :installed?
      end
    end

    assert_equal attempt.public_id, queried_attempt
    assert_equal 1, RpCoreAppRefreshAttempt.count
    assert_equal 1, @session.reload.installed_generation
  end

  test "dependency and invalid remote outcomes retain an uncertain attempt and expired attempts cannot redispatch" do
    [:dependency, :invalid_remote].each do |outcome|
      session = RpCallbackCommitter.call(
        cell: @cell, issuer: ISSUER, subject: "subject-#{outcome}", sid: "sid-#{outcome}",
        absolute_expires_at: 1.hour.from_now,
      ).session
      arguments = {
        cell: @cell,
        local_session_id: session.public_id,
        refresh_token: "refresh-plain",
        issuer: ISSUER,

        jwks_client: nil,
        token_url: "#{ISSUER}/oauth/token",
        query_url: "#{ISSUER}/oauth/refresh-deliveries/query",
      }
      response = Outcome.new(outcome: outcome, token_response: nil, error: "unavailable")

      OidcOpTokenClient.stub(:refresh, response) do
        assert_equal :dependency, RpRefreshCommitter.call(**arguments).outcome
      end
      attempt = RpCoreAppRefreshAttempt.find_by!(session_id: session.id)

      assert_not_nil attempt.uncertain_at
      attempt.update!(expires_at: 1.second.ago)
      OidcOpTokenClient.stub(:refresh, ->(**) { flunk("expired attempts must not rotate") }) do
        OidcOpTokenClient.stub(:query_delivery, ->(**) { flunk("expired attempts must not query") }) do
          assert_equal :refused, RpRefreshCommitter.call(**arguments).outcome
        end
      end

      assert_equal 1, RpCoreAppRefreshAttempt.where(session_id: session.id).count
    end
  end

  test "another tab observes the pending attempt without dispatching a second rotation" do
    arguments = {
      cell: @cell,
      local_session_id: @session.public_id,
      refresh_token: "refresh-plain",
      issuer: ISSUER,

      jwks_client: nil,
      token_url: "#{ISSUER}/oauth/token",
      query_url: "#{ISSUER}/oauth/refresh-deliveries/query",
    }
    dispatches = 0

    OidcOpTokenClient.stub(
      :refresh, ->(**) {
                  dispatches += 1

                  assert_equal 1, dispatches
                  assert_equal :superseded, RpRefreshCommitter.call(**arguments).outcome
                  Outcome.new(outcome: :dependency, token_response: nil, error: "unavailable")
                },
    ) do
      assert_equal :dependency, RpRefreshCommitter.call(**arguments).outcome
    end
    assert_equal 1, RpCoreAppRefreshAttempt.count
    assert_equal 0, @session.reload.installed_generation
  end

  test "late installation obeys the attempt deadline one microsecond before at and after expiry" do
    base = Time.current.change(usec: 0)
    [-Rational(1, 1_000_000), 0, Rational(1, 1_000_000)].each_with_index do |offset, index|
      session = RpCallbackCommitter.call(
        cell: @cell, issuer: ISSUER, subject: "subject-deadline", sid: "deadline-#{index}",
        absolute_expires_at: base + 1.hour,
      ).session
      access = JWT.encode(
        { "iss" => ISSUER,
          "aud" => ["core-app-jp"],
          "exp" => base.to_i + 300,
          "nbf" => base.to_i - 5,
          "iat" => base.to_i - 5,
          "sub" => "subject-deadline",
          "sid" => "deadline-#{index}",
          "client_id" => "core-app-jp",
          "jti" => "deadline-#{index}",
          "scope" => "openid",
          "authn_ctx" => "normal", },
        @key, "ES384", { "kid" => "k1", "typ" => "at+jwt" },
      )
      jwks = OidcOpJwksClient.new(
        jwks_uri: "#{ISSUER}/.well-known/jwks.json",
        fetcher: -> { { "keys" => [JitSecurityJwtJwk.export_public(@key, kid: "k1")] } },
      )
      now = base
      response = Outcome.new(
        outcome: :success, token_response: { access_token: access, refresh_token: "next" },
        error: nil,
      )
      RpCoreAppRecord.stub(:database_now, -> { now }) do
        OidcOpTokenClient.stub(
          :refresh, ->(**) {
                      now = base + RpRefreshCommitter::ATTEMPT_TTL + offset
                      response
                    },
        ) do
          result = RpRefreshCommitter.call(
            cell: @cell, local_session_id: session.public_id, refresh_token: "refresh-plain", issuer: ISSUER,
            jwks_client: jwks, token_url: "#{ISSUER}/oauth/token",
            query_url: "#{ISSUER}/oauth/refresh-deliveries/query",
          )

          assert_equal offset.negative? ? :installed : :refused, result.outcome
          assert_equal offset.negative? ? 1 : 0, session.reload.installed_generation
        end
      end
    end
  end

  test "a lost browser response recovers installed credentials once without rotating the predecessor again" do
    access = JWT.encode(
      { "iss" => ISSUER,
        "aud" => ["core-app-jp"],
        "exp" => Time.current.to_i + 300,
        "nbf" => Time.current.to_i - 5,
        "iat" => Time.current.to_i - 5,
        "sub" => "subject-a",
        "sid" => "sid-1",
        "client_id" => "core-app-jp",
        "jti" => "installed-response",
        "scope" => "openid",
        "authn_ctx" => "normal", },
      @key, "ES384", { "kid" => "k1", "typ" => "at+jwt" },
    )
    jwks = OidcOpJwksClient.new(
      jwks_uri: "#{ISSUER}/.well-known/jwks.json",
      fetcher: -> { { "keys" => [JitSecurityJwtJwk.export_public(@key, kid: "k1")] } },
    )
    arguments = {
      cell: @cell,
      local_session_id: @session.public_id,
      refresh_token: "refresh-plain",
      issuer: ISSUER,

      jwks_client: jwks,
      token_url: "#{ISSUER}/oauth/token",
      query_url: "#{ISSUER}/oauth/refresh-deliveries/query",
    }
    response = Outcome.new(
      outcome: :success, token_response: { access_token: access, refresh_token: "next" },
      error: nil,
    )

    OidcOpTokenClient.stub(:refresh, response) do
      assert_predicate RpRefreshCommitter.call(**arguments), :installed?
    end
    attempt = RpCoreAppRefreshAttempt.sole
    OidcOpTokenClient.stub(:refresh, ->(**) { flunk("a known predecessor must never rotate again") }) do
      OidcOpTokenClient.stub(:query_delivery, response) do
        result = RpRefreshCommitter.call(**arguments)

        assert_predicate result, :installed?
        assert_equal response.token_response, result.token_response
      end
      attempt.update!(expires_at: 1.second.ago)

      OidcOpTokenClient.stub(:query_delivery, ->(**) { flunk("the original receipt window must not reopen") }) do
        assert_equal :refused, RpRefreshCommitter.call(**arguments).outcome
      end
    end

    assert_equal 1, @session.reload.installed_generation
    assert_equal 1, RpCoreAppRefreshAttempt.count
  end

  test "installation immediately before at and after the total dispatch deadline preserves generation" do
    [-0.001, 0.0, 0.001].each_with_index do |offset, index|
      session = RpCallbackCommitter.call(
        cell: @cell, issuer: ISSUER, subject: "budget-subject", sid: "budget-#{index}",
        absolute_expires_at: 1.hour.from_now,
      ).session
      now = Time.current.to_i
      access = JWT.encode(
        { "iss" => ISSUER,
          "aud" => [@cell.client_id],
          "exp" => now + 300,
          "nbf" => now - 5,
          "iat" => now - 5,
          "sub" => "budget-subject",
          "sid" => "budget-#{index}",
          "client_id" => @cell.client_id,
          "jti" => "budget-#{index}",
          "scope" => "openid",
          "authn_ctx" => "normal", },
        @key, "ES384", { "kid" => "k1", "typ" => "at+jwt" },
      )
      keys = OidcOpJwksClient.new(
        jwks_uri: "#{ISSUER}/.well-known/jwks.json",
        fetcher: -> { { "keys" => [JitSecurityJwtJwk.export_public(@key, kid: "k1")] } },
      )
      monotonic = 100.0
      response = Outcome.new(outcome: :success, token_response: { access_token: access }, error: nil)
      Process.stub(:clock_gettime, ->(*) { monotonic }) do
        OidcOpTokenClient.stub(
          :refresh, ->(**arguments) {
                      assert_in_delta 104.0, arguments.fetch(:deadline), 0.001
                      monotonic += RpRefreshCommitter::DISPATCH_BUDGET + offset
                      response
                    },
        ) do
          result = RpRefreshCommitter.call(
            cell: @cell, local_session_id: session.public_id, refresh_token: "refresh-plain", issuer: ISSUER,
            jwks_client: keys, token_url: "#{ISSUER}/oauth/token",
            query_url: "#{ISSUER}/oauth/refresh-deliveries/query",
          )

          assert_equal offset.negative? ? :installed : :dependency, result.outcome
          assert_equal offset.negative? ? 1 : 0, session.reload.installed_generation
          assert_not_nil RpCoreAppRefreshAttempt.find_by!(session_id: session.id).uncertain_at unless offset.negative?
        end
      end
    end
  end

  test "receipt recovery keeps the original total deadline after an uncertain exchange" do
    monotonic = 100.0
    timeout = Outcome.new(outcome: :indeterminate, token_response: nil, error: "timeout")
    unavailable = Outcome.new(outcome: :dependency, token_response: nil, error: "unavailable")
    Process.stub(:clock_gettime, ->(*) { monotonic }) do
      OidcOpTokenClient.stub(
        :refresh, ->(**arguments) {
                    assert_in_delta 104.0, arguments.fetch(:deadline), 0.001
                    monotonic = 103.5
                    timeout
                  },
      ) do
        OidcOpTokenClient.stub(
          :query_delivery, ->(**arguments) {
                             assert_in_delta 104.0, arguments.fetch(:deadline), 0.001
                             unavailable
                           },
        ) do
          result = RpRefreshCommitter.call(
            cell: @cell, local_session_id: @session.public_id, refresh_token: "refresh-plain", issuer: ISSUER,
            jwks_client: nil, token_url: "#{ISSUER}/oauth/token",
            query_url: "#{ISSUER}/oauth/refresh-deliveries/query",
          )

          assert_equal :dependency, result.outcome
          assert_equal 0, @session.reload.installed_generation
          assert_not_nil RpCoreAppRefreshAttempt.sole.uncertain_at
        end
      end
    end
  end

  test "an unverifiable successful OP response preserves recovery instead of rejecting browser credentials" do
    keys = OidcOpJwksClient.new(
      jwks_uri: "#{ISSUER}/.well-known/jwks.json",
      fetcher: -> { { "keys" => [JitSecurityJwtJwk.export_public(@key, kid: "k1")] } },
    )
    response = Outcome.new(outcome: :success, token_response: { access_token: "invalid-jwt" }, error: nil)
    arguments = {
      cell: @cell,
      local_session_id: @session.public_id,
      refresh_token: "refresh-plain",
      issuer: ISSUER,

      jwks_client: keys,
      token_url: "#{ISSUER}/oauth/token",
      query_url: "#{ISSUER}/oauth/refresh-deliveries/query",
    }

    OidcOpTokenClient.stub(:refresh, response) do
      assert_equal :dependency, RpRefreshCommitter.call(**arguments).outcome
    end
    attempt = RpCoreAppRefreshAttempt.sole

    assert_not_nil attempt.uncertain_at
    assert_nil attempt.installed_at
    assert_equal 0, @session.reload.installed_generation
    OidcOpTokenClient.stub(:refresh, ->(**) { flunk("malformed success may already have committed") }) do
      OidcOpTokenClient.stub(
        :query_delivery, ->(**parameters) {
                           assert_equal attempt.public_id, parameters.fetch(:attempt_ref)
                           response
                         },
      ) do
        assert_equal :dependency, RpRefreshCommitter.call(**arguments).outcome
      end
    end

    assert_equal 1, RpCoreAppRefreshAttempt.count
    assert_equal 0, @session.reload.installed_generation
  end

  private

  def refresh(token:, query: ->(**) { flunk("no query expected") })
    OidcOpTokenClient.stub(:refresh, token) do
      OidcOpTokenClient.stub(:query_delivery, query) do
        RpRefreshCommitter.call(
          cell: @cell, local_session_id: @session.public_id, refresh_token: "refresh-plain",
          issuer: ISSUER,
          jwks_client: jwks, token_url: "#{ISSUER}/oauth/token", query_url: "#{ISSUER}/oauth/refresh-deliveries/query",
        )
      end
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
