# typed: false
# frozen_string_literal: true

require "test_helper"

# The Google strategy establishes a uid only from an ID token verified against Google's published
# JWKS. The JWKS endpoint is the external boundary here, so it is the only thing replaced: a
# healthy key set verifies the token, and every broken answer from that endpoint (error status,
# non-JSON body, wrong document shape, transport failure) refuses the callback as an invalid ID
# token instead of leaking a raw error or accepting the token.
class OmniauthGoogleJwksBoundaryTest < ActiveSupport::TestCase
  ENFORCEMENT = ExternalAuthenticationInfrastructureOmniauthGoogleOidcEnforcement

  setup { Rails.cache.delete(ENFORCEMENT::JWKS_CACHE_KEY) }
  teardown { Rails.cache.delete(ENFORCEMENT::JWKS_CACHE_KEY) }

  test "an ID token signed by a key in Google's published JWKS establishes the uid" do
    signing_key = OpenSSL::PKey::RSA.generate(2048)
    jwks = { "keys" => [JWT::JWK.new(signing_key.public_key, kid: "google-key").export] }
    id_token = JWT.encode(
      { "iss" => "https://accounts.google.com",
        "aud" => "contract-client",
        "sub" => "google-subject",
        "nonce" => "n",
        "iat" => Time.current.to_i,
        "exp" => 5.minutes.from_now.to_i, },
      signing_key, "RS256", { kid: "google-key" },
    )
    strategy = OmniAuth::Strategies::GoogleOauth2.new(->(_env) { [200, {}, ["ok"]] }, "contract-client", "secret")
    env = Rack::MockRequest.env_for("/social/google/callback")
    env["rack.session"] = { "omniauth.nonce" => "n" }
    strategy.instance_variable_set(:@env, env)
    strategy.access_token = OAuth2::AccessToken.new(
      OAuth2::Client.new("contract-client", "secret"), "at",
      "id_token" => id_token,
    )
    stubs = Faraday::Adapter::Test::Stubs.new { |s| s.get(ENFORCEMENT::JWKS_URI.to_s) { [200, {}, jwks.to_json] } }

    stub_outbound_http(stubs) do
      assert_equal "google-subject", strategy.uid
    end
  end

  test "a broken JWKS answer refuses the ID token" do
    signing_key = OpenSSL::PKey::RSA.generate(2048)
    id_token = JWT.encode(
      { "iss" => "https://accounts.google.com",
        "aud" => "contract-client",
        "sub" => "google-subject",
        "nonce" => "n",
        "iat" => Time.current.to_i,
        "exp" => 5.minutes.from_now.to_i, },
      signing_key, "RS256", { kid: "google-key" },
    )
    answers = {
      "error status" => -> { [500, {}, "ERR"] },
      "non-JSON body" => -> { [200, {}, "not-json"] },
      "keys that are not a list" => -> { [200, {}, '{"keys":"nope"}'] },
      "connection failure" => -> { raise Faraday::ConnectionFailed, "refused" },
      "timeout" => -> { raise Faraday::TimeoutError, "read timeout" },
    }

    answers.each do |label, answer|
      Rails.cache.delete(ENFORCEMENT::JWKS_CACHE_KEY)
      strategy = OmniAuth::Strategies::GoogleOauth2.new(->(_env) { [200, {}, ["ok"]] }, "contract-client", "secret")
      env = Rack::MockRequest.env_for("/social/google/callback")
      env["rack.session"] = { "omniauth.nonce" => "n" }
      strategy.instance_variable_set(:@env, env)
      strategy.access_token = OAuth2::AccessToken.new(
        OAuth2::Client.new("contract-client", "secret"), "at",
        "id_token" => id_token,
      )
      stubs = Faraday::Adapter::Test::Stubs.new { |s| s.get(ENFORCEMENT::JWKS_URI.to_s) { answer.call } }

      stub_outbound_http(stubs) do
        error = assert_raises(OmniAuth::Strategies::OAuth2::CallbackError, label) { strategy.uid }

        assert_equal :invalid_id_token, error.error, label
      end
    end
  end
  # The callback compares the returned state against the one the request phase stored in the
  # session. A session that lost it is a CSRF failure, not a crash in the comparison.
  test "a callback whose session holds no state fails as csrf_detected" do
    strategy = OmniAuth::Strategies::GoogleOauth2.new(
      ->(_env) { [200, {}, ["ok"]] }, "contract-client", "secret", name: "google",
    )
    env = Rack::MockRequest.env_for("/social/google/callback?state=returned-state&code=c")
    env["rack.session"] = {}
    test_mode = OmniAuth.config.test_mode
    OmniAuth.config.test_mode = false

    status, headers, = strategy.call(env)

    assert_equal 302, status
    assert_equal "/social/failure?message=csrf_detected&strategy=google", headers["Location"]
  ensure
    OmniAuth.config.test_mode = test_mode
  end

  # Equivalence partitions of the callback state at the real middleware entry, with the boundary
  # values the comparison can meet: missing, empty, a non-String session value, a non-String request
  # value (Rack parses `state[]=` into an Array), equal-length and different-length mismatches, and
  # a NUL byte. Each is refused as csrf_detected; none raises.
  STATE_REJECTIONS = {
    "session state missing" => [{}, "state=returned-state"],
    "session state empty" => [{ "omniauth.state" => "" }, "state=returned-state"],
    "session state not a String" => [{ "omniauth.state" => 0 }, "state=0"],
    "request state missing" => [{ "omniauth.state" => "stored-state" }, ""],
    "request state empty" => [{ "omniauth.state" => "stored-state" }, "state="],
    "request state an Array" => [{ "omniauth.state" => "stored-state" }, "state[]=stored-state"],
    "same length mismatch" => [{ "omniauth.state" => "stored-state" }, "state=stored-statf"],
    "different length mismatch" => [{ "omniauth.state" => "stored-state" }, "state=stored-state-longer"],
    "NUL byte appended" => [{ "omniauth.state" => "stored-state" }, "state=stored-state%00"],
  }.freeze

  STATE_REJECTIONS.each do |label, (session, query)|
    test "callback state #{label} is refused as csrf_detected" do
      strategy = OmniAuth::Strategies::GoogleOauth2.new(
        ->(_env) { [200, {}, ["ok"]] }, "contract-client", "secret", name: "google",
      )
      env = Rack::MockRequest.env_for("/social/google/callback?#{[query, "code=c"].compact_blank.join("&")}")
      env["rack.session"] = session.dup
      test_mode = OmniAuth.config.test_mode
      OmniAuth.config.test_mode = false

      status, headers, = strategy.call(env)

      assert_equal 302, status
      assert_equal "/social/failure?message=csrf_detected&strategy=google", headers["Location"]
    ensure
      OmniAuth.config.test_mode = test_mode
    end
  end

  # The nonce claim partitions: equal String (accepted above), missing, empty, a number that would
  # equal the stored nonce if converted, and a different String. Only the equal String verifies.
  NONCE_REJECTIONS = {
    "nonce claim missing" => [:absent, "n"],
    "nonce claim empty" => ["", "n"],
    "nonce claim a number whose string form matches" => [7, "7"],
    "nonce claim a different String" => ["m", "n"],
    "stored nonce missing" => ["n", nil],
    "stored nonce empty" => ["n", ""],
  }.freeze

  NONCE_REJECTIONS.each do |label, (claim, stored)|
    test "ID token #{label} is refused" do
      signing_key = OpenSSL::PKey::RSA.generate(2048)
      jwks = { "keys" => [JWT::JWK.new(signing_key.public_key, kid: "google-key").export] }
      claims = {
        "iss" => "https://accounts.google.com",
        "aud" => "contract-client",
        "sub" => "google-subject",
        "iat" => Time.current.to_i,
        "exp" => 5.minutes.from_now.to_i,
      }
      claims["nonce"] = claim unless claim == :absent
      id_token = JWT.encode(claims, signing_key, "RS256", { kid: "google-key" })
      strategy = OmniAuth::Strategies::GoogleOauth2.new(->(_env) { [200, {}, ["ok"]] }, "contract-client", "secret")
      env = Rack::MockRequest.env_for("/social/google/callback")
      env["rack.session"] = stored.nil? ? {} : { "omniauth.nonce" => stored }
      strategy.instance_variable_set(:@env, env)
      strategy.access_token = OAuth2::AccessToken.new(
        OAuth2::Client.new("contract-client", "secret"), "at",
        "id_token" => id_token,
      )
      stubs = Faraday::Adapter::Test::Stubs.new { |s| s.get(ENFORCEMENT::JWKS_URI.to_s) { [200, {}, jwks.to_json] } }

      stub_outbound_http(stubs) do
        error = assert_raises(OmniAuth::Strategies::OAuth2::CallbackError) { strategy.uid }

        assert_includes %i(invalid_id_token invalid_nonce), error.error
      end
    end
  end
end
