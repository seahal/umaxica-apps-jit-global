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
end
