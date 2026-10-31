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

  test "each Visa host serves its own public root without issuing cookies" do
    {
      "visa.umaxica.app" => ["visa/app/roots", "Visa App"],
      "visa.umaxica.org" => ["visa/org/roots", "Visa Org"],
      "visa.app.localhost" => ["visa/app/roots", "Visa App"],
      "visa.org.localhost" => ["visa/org/roots", "Visa Org"],
    }.each do |host, (controller, heading)|
      host! host
      get "/"

      assert_response :found
      assert_equal "jp", Rack::Utils.parse_nested_query(URI.parse(response.location).query).fetch("ri")
      assert_nil response.headers["Set-Cookie"]
      follow_redirect!

      assert_response :ok
      assert_equal controller, request.path_parameters[:controller]
      assert_equal "text/html", response.media_type
      assert_select "title", heading
      assert_select "main h1", heading
      assert_select "header .ui-landing__brand", text: /VISA/
      assert_select "main .ui-landing__intro p", text: I18n.t("landing.thin_endpoint")
      assert_select "main a.ui-button", text: I18n.t("landing.sign_in")
      assert_select "footer nav a", text: I18n.t("ui_presentation.navigation.preferences")
      assert_includes response.headers.fetch("Cache-Control"), "no-store"
      assert_nil response.headers["Set-Cookie"]

      head "/", params: { ri: "jp" }

      assert_response :ok
      assert_empty response.body
      assert_nil response.headers["Set-Cookie"]
    end
  end

  test "landing destinations use the matching Base origin and preserve supplied region" do
    hosts = Rails.configuration.x.boot_config.fetch(:hosts)
    {
      "visa.app.localhost" => hosts.base_service,
      "visa.org.localhost" => hosts.base_staff,
    }.each do |host, origin|
      host! host
      get "/", params: { ri: "us" }

      assert_response :ok
      assert_select "main a.ui-button[href='#{origin}/sign?ri=us']", count: 1
      assert_select "footer nav a[href='#{origin}/preference?ri=us']", count: 1
      assert_select "form", count: 0
      assert_nil response.headers["Set-Cookie"]
    end
  end

  test "landing ignores a retired item theme cookie without writing cookies" do
    host! "visa.app.localhost"
    cookies[:ct] = "dr"
    get "/", params: { ri: "jp" }

    assert_response :ok
    assert_select "html[data-theme=system]"
    assert_select "a.ui-skip-link[href='#main']"
    assert_select "main#main[tabindex='-1']"
    assert_nil response.headers["Set-Cookie"]
  end

  test "landing copy is available in both supported languages" do
    host! "visa.app.localhost"
    %i(en ja).each do |locale|
      I18n.with_locale(locale) do
        get "/", params: { ri: "jp" }

        assert_response :ok
        assert_select "html[lang='#{locale}']"
        assert_select "main a.ui-button", text: I18n.t("landing.sign_in")
        assert_select "main .ui-landing__intro p", text: I18n.t("landing.thin_endpoint")
        assert_nil response.headers["Set-Cookie"]
      end
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
