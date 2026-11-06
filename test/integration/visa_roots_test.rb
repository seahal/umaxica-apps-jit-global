# frozen_string_literal: true

require "test_helper"

class VisaRootsTest < ActionDispatch::IntegrationTest
  self.fixture_table_names = []

  test "Visa APP and ORG DBSC registration refuse a missing session without creating tokens" do
    [ENV.fetch("PUBLIC_VISA_SERVICE_URL"), ENV.fetch("PUBLIC_VISA_STAFF_URL")].each do |host|
      browser = open_session
      browser.host!(host)
      browser.https!
      assert_no_difference ["ClientToken.count", "OperatorToken.count"] do
        browser.post("/edge/v0/token/dbsc", params: {}, as: :json)
      end

      assert_equal 422, browser.response.status
      assert_equal "record_missing", browser.response.parsed_body.fetch("error_code")
      assert_not browser.response.cookies.key?(AuthenticationBase::DBSC_COOKIE_KEY)
    end
  end

  test "authenticated Visa APP and ORG checks advertise realm-local DBSC registration" do
    [
      {
        host: ENV.fetch("PUBLIC_VISA_SERVICE_URL"),
        resource_type: "client",
        owner_attribute: :user,
        actor: lambda {
          Client.create!(
            security_mode_id: SecurityModeConfigurable::NORMAL,
            status_id: ClientStatus::ACTIVE,
          )
        },
        token_class: ClientToken,
      },
      {
        host: ENV.fetch("PUBLIC_VISA_STAFF_URL"),
        resource_type: "operator",
        owner_attribute: :staff,
        actor: lambda {
          Operator.create!(
            security_mode_id: SecurityModeConfigurable::ADVANCED,
            status_id: OperatorStatus::ACTIVE,
          )
        },
        token_class: OperatorToken,
      },
    ].each do |configuration|
      actor = configuration.fetch(:actor).call
      token_attributes = { authentication_epoch: 0 }
      token_attributes[configuration.fetch(:owner_attribute)] = actor
      token = configuration.fetch(:token_class).create!(**token_attributes)
      token.rotate_refresh_token!
      host = configuration.fetch(:host)
      access_token = jwt_access_token_for(
        actor,
        host: host,
        session_public_id: token.public_id,
        resource_type: configuration.fetch(:resource_type),
      )
      browser = open_session
      browser.host!(host)
      browser.https!
      browser.cookies[AuthenticationBase::ACCESS_COOKIE_KEY] = access_token

      browser.get("/edge/v0/token/check", headers: { "Accept" => "application/json" })

      assert_equal 200, browser.response.status, host
      assert browser.response.parsed_body.fetch("authenticated")

      registration = browser.response.headers[AuthIoKeys::Headers::SECURE_DBSC_REGISTRATION]

      assert_predicate registration, :present?, host
      assert_equal registration, browser.response.headers[AuthIoKeys::Headers::DBSC_REGISTRATION], host
      assert_includes registration, "(ES256 RS256);", host
      assert_includes registration, 'path="/edge/v0/token/dbsc"', host
      assert_includes registration, "challenge=", host
      assert_predicate token.reload.dbsc_challenge, :present?, host
    end
  end

  test "Visa DBSC challenge expiry is strict at the five-minute boundary for APP and ORG" do
    now = Time.current.change(usec: 0)
    travel_to(now) do
      %w(app org).each do |surface|
        [-1, 0, 1].each do |offset|
          case surface
          when "app"
            actor = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE)
            token = ClientToken.create!(authentication_epoch: 0, user: actor)
            host = ENV.fetch("PUBLIC_VISA_SERVICE_URL")
          when "org"
            actor = Operator.create!(security_mode_id: SecurityModeConfigurable::ADVANCED, status_id: OperatorStatus::ACTIVE)
            token = OperatorToken.create!(authentication_epoch: 0, staff: actor)
            host = ENV.fetch("PUBLIC_VISA_STAFF_URL")
          else
            raise ArgumentError, "unsupported Visa surface"
          end
          token.update!(
            dbsc_challenge: SecureRandom.hex(16),
            dbsc_challenge_issued_at: now - DbscProofVerifier::CHALLENGE_TTL + Rational(offset, 1_000_000),
          )
          browser = open_session
          browser.host!(host)
          browser.https!
          browser.cookies[AuthenticationBase::REFRESH_COOKIE_KEY] = token.rotate_refresh_token!
          key = OpenSSL::PKey::EC.generate("prime256v1")
          jwk = JWT::JWK.new(key, use: "sig", kid: SecureRandom.uuid)
          proof = JWT.encode(
            { "jti" => token.reload.dbsc_challenge,
              "aud" => "https://#{host}/edge/v0/token/dbsc",
              "iat" => now.to_i, }, key, "ES256", { "typ" => "dbsc+jwt", "jwk" => jwk.export },
          )
          browser.post(
            "/edge/v0/token/dbsc",
            params: {},
            as: :json,
            headers: { AuthIoKeys::Headers::SECURE_DBSC_RESPONSE => DbscHeaderSerializer.string(proof) },
          )

          assert_equal(offset.negative? ? 422 : 201, browser.response.status, "#{surface} offset #{offset}")
          if offset.negative?
            assert_equal "challenge_expired", browser.response.parsed_body.fetch("error_code")
            assert_not browser.response.cookies.key?(AuthenticationBase::DBSC_COOKIE_KEY)
          else
            assert_predicate browser.response.cookies[AuthenticationBase::DBSC_COOKIE_KEY], :present?
          end
        end
      end
    end
  end

  test "Visa APP DBSC registration accepts a session-bound proof and rejects a wrong audience" do
    actor = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE)
    token = ClientToken.create!(authentication_epoch: 0, user: actor)
    token.update!(dbsc_challenge: SecureRandom.hex(16), dbsc_challenge_issued_at: ClientToken.database_now)
    browser = open_session
    host = ENV.fetch("PUBLIC_VISA_SERVICE_URL")
    browser.host!(host)
    browser.https!
    browser.cookies[AuthenticationBase::REFRESH_COOKIE_KEY] = token.rotate_refresh_token!
    key = OpenSSL::PKey::EC.generate("prime256v1")
    jwk = JWT::JWK.new(key, use: "sig", kid: SecureRandom.uuid)
    wrong_host = ENV.fetch("PUBLIC_VISA_STAFF_URL")
    payload = { "jti" => token.reload.dbsc_challenge,
                "aud" => "https://#{wrong_host}/edge/v0/token/dbsc",
                "iat" => Time.current.to_i, }
    proof = JWT.encode(payload, key, "ES256", { "typ" => "dbsc+jwt", "jwk" => jwk.export })
    browser.post(
      "/edge/v0/token/dbsc",
      params: {},
      as: :json,
      headers: { AuthIoKeys::Headers::SECURE_DBSC_RESPONSE => DbscHeaderSerializer.string(proof) },
    )

    assert_equal 422, browser.response.status
    assert_equal "audience_mismatch", browser.response.parsed_body.fetch("error_code")
    assert_not browser.response.cookies.key?(AuthenticationBase::DBSC_COOKIE_KEY)
    assert_predicate token.reload.dbsc_challenge, :present?

    payload["aud"] = "https://#{host}/edge/v0/token/dbsc"
    wrong_key = OpenSSL::PKey::EC.generate("prime256v1")
    forged = JWT.encode(payload, wrong_key, "ES256", { "typ" => "dbsc+jwt", "jwk" => jwk.export })
    browser.post(
      "/edge/v0/token/dbsc",
      params: {},
      as: :json,
      headers: { AuthIoKeys::Headers::SECURE_DBSC_RESPONSE => DbscHeaderSerializer.string(forged) },
    )

    assert_equal 422, browser.response.status
    assert_equal "invalid_proof", browser.response.parsed_body.fetch("error_code")
    assert_not browser.response.cookies.key?(AuthenticationBase::DBSC_COOKIE_KEY)
    assert_predicate token.reload.dbsc_challenge, :present?

    proof = JWT.encode(payload, key, "ES256", { "typ" => "dbsc+jwt", "jwk" => jwk.export })
    browser.post(
      "/edge/v0/token/dbsc",
      params: {},
      as: :json,
      headers: { AuthIoKeys::Headers::SECURE_DBSC_RESPONSE => DbscHeaderSerializer.string(proof) },
    )

    assert_equal 201, browser.response.status
    assert_predicate browser.response.cookies[AuthenticationBase::DBSC_COOKIE_KEY], :present?
    assert_equal ClientTokenDbscStatus::ACTIVE, token.reload.user_token_dbsc_status_id
    assert_nil token.dbsc_challenge

    browser.post(
      "/edge/v0/token/dbsc",
      params: {},
      as: :json,
      headers: { AuthIoKeys::Headers::SECURE_DBSC_RESPONSE => DbscHeaderSerializer.string(proof) },
    )

    assert_equal 422, browser.response.status
    assert_equal "missing_challenge", browser.response.parsed_body.fetch("error_code")
    assert_not browser.response.cookies.key?(AuthenticationBase::DBSC_COOKIE_KEY)
  end

  test "Visa ORG DBSC registration accepts a session-bound proof and rejects a wrong audience" do
    actor = Operator.create!(security_mode_id: SecurityModeConfigurable::ADVANCED, status_id: OperatorStatus::ACTIVE)
    token = OperatorToken.create!(authentication_epoch: 0, staff: actor)
    token.update!(dbsc_challenge: SecureRandom.hex(16), dbsc_challenge_issued_at: OperatorToken.database_now)
    browser = open_session
    host = ENV.fetch("PUBLIC_VISA_STAFF_URL")
    browser.host!(host)
    browser.https!
    browser.cookies[AuthenticationBase::REFRESH_COOKIE_KEY] = token.rotate_refresh_token!
    key = OpenSSL::PKey::EC.generate("prime256v1")
    jwk = JWT::JWK.new(key, use: "sig", kid: SecureRandom.uuid)
    wrong_host = ENV.fetch("PUBLIC_VISA_SERVICE_URL")
    payload = { "jti" => token.reload.dbsc_challenge,
                "aud" => "https://#{wrong_host}/edge/v0/token/dbsc",
                "iat" => Time.current.to_i, }
    proof = JWT.encode(payload, key, "ES256", { "typ" => "dbsc+jwt", "jwk" => jwk.export })
    browser.post(
      "/edge/v0/token/dbsc",
      params: {},
      as: :json,
      headers: { AuthIoKeys::Headers::SECURE_DBSC_RESPONSE => DbscHeaderSerializer.string(proof) },
    )

    assert_equal 422, browser.response.status
    assert_equal "audience_mismatch", browser.response.parsed_body.fetch("error_code")
    assert_not browser.response.cookies.key?(AuthenticationBase::DBSC_COOKIE_KEY)
    assert_predicate token.reload.dbsc_challenge, :present?

    payload["aud"] = "https://#{host}/edge/v0/token/dbsc"
    wrong_key = OpenSSL::PKey::EC.generate("prime256v1")
    forged = JWT.encode(payload, wrong_key, "ES256", { "typ" => "dbsc+jwt", "jwk" => jwk.export })
    browser.post(
      "/edge/v0/token/dbsc",
      params: {},
      as: :json,
      headers: { AuthIoKeys::Headers::SECURE_DBSC_RESPONSE => DbscHeaderSerializer.string(forged) },
    )

    assert_equal 422, browser.response.status
    assert_equal "invalid_proof", browser.response.parsed_body.fetch("error_code")
    assert_not browser.response.cookies.key?(AuthenticationBase::DBSC_COOKIE_KEY)
    assert_predicate token.reload.dbsc_challenge, :present?

    proof = JWT.encode(payload, key, "ES256", { "typ" => "dbsc+jwt", "jwk" => jwk.export })
    browser.post(
      "/edge/v0/token/dbsc",
      params: {},
      as: :json,
      headers: { AuthIoKeys::Headers::SECURE_DBSC_RESPONSE => DbscHeaderSerializer.string(proof) },
    )

    assert_equal 201, browser.response.status
    assert_predicate browser.response.cookies[AuthenticationBase::DBSC_COOKIE_KEY], :present?
    assert_equal OperatorTokenDbscStatus::ACTIVE, token.reload.staff_token_dbsc_status_id
    assert_nil token.dbsc_challenge

    browser.post(
      "/edge/v0/token/dbsc",
      params: {},
      as: :json,
      headers: { AuthIoKeys::Headers::SECURE_DBSC_RESPONSE => DbscHeaderSerializer.string(proof) },
    )

    assert_equal 422, browser.response.status
    assert_equal "missing_challenge", browser.response.parsed_body.fetch("error_code")
    assert_not browser.response.cookies.key?(AuthenticationBase::DBSC_COOKIE_KEY)
  end

  test "the Visa hosts route nothing at the root" do
    %w(visa.umaxica.app visa.umaxica.org visa.app.localhost visa.org.localhost).each do |host|
      host! host
      get "/", params: { ri: "jp" }

      assert_response :not_found
      assert_nil response.headers["Set-Cookie"]
    end
  end

  test "the corporate Visa host and look-alike hosts remain unknown" do
    # two.md WU-3: the corporate host owns no OIDC protocol, so it claims no root either.
    %w(visa.umaxica.com visa.com.localhost
       visa.umaxica.app.example visa.umaxica.com.example visa.umaxica.org.example).each do |host|
      host! host
      get "/"

      assert_response :not_found
      assert_equal "unknown_host", response.parsed_body.fetch("error")
    end
  end
end
