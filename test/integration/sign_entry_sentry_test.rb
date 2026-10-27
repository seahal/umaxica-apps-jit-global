# typed: false
# frozen_string_literal: true

require "test_helper"

class SignEntrySentryTest < ActionDispatch::IntegrationTest
  self.fixture_table_names = []

  SURFACES = {
    app: ENV.fetch("PUBLIC_AUTH_SERVICE_URL"),
    com: ENV.fetch("PUBLIC_AUTH_CORPORATE_URL"),
    org: ENV.fetch("PUBLIC_AUTH_STAFF_URL"),
  }.freeze

  FLOWS = %i(sign_in sign_up).freeze

  test "A07-2: a retryable sentry refusal keeps flow locators and Auth continuity" do
    host = SURFACES.fetch(:app)
    Flipper.disable(FeatureFlags::REGISTRY.fetch(:sign_in_available_app).name)
    continuity = {
      app_sign_in_flow_locator: { "public_id" => "signin-flow", "nonce" => "signin-nonce" },
      app_sign_up_flow_locator: { "public_id" => "signup-flow", "nonce" => "signup-nonce" },
      auth_app_up_sequence_id: "signup-sequence",
      social_auth_intent: "signup",
      social_auth_flow_id: "social-flow",
      social_auth_provider: "google",
      social_auth_state: "social-state",
      social_auth_state_started_at: 1_761_408_000,
      social_auth_state_provider: "google",
    }
    sid_cookie = JitSessionCookieConfig.force_secure? ? "__Host-auth_sid" : "auth_sid"
    session_cookie_value = "retained-auth-continuity"
    session_key = Rails.application.config.session_options.fetch(:key)
    cookie_request = ActionDispatch::TestRequest.create
    jar = ActionDispatch::Cookies::CookieJar.build(cookie_request, {})
    jar.encrypted[session_key] = {
      value: {
        "session_id" => SecureRandom.hex(16),
        "_csrf_token" => SecureRandom.urlsafe_base64(32),
      }.merge(continuity.transform_keys(&:to_s)),
    }
    browser = open_session
    browser.host!(host)
    browser.https!
    store_raw_cookies(
      browser.cookies, "#{session_key}=#{Rack::Utils.escape(jar[session_key])}", URI.parse("https://#{host}/"),
    )
    store_raw_cookies(
      browser.cookies, "#{sid_cookie}=#{Rack::Utils.escape(session_cookie_value)}", URI.parse("https://#{host}/"),
    )

    browser.get("/sign/in/sentry", params: { ri: "jp" })

    assert_equal 503, browser.response.status
    retained = ActionDispatch::Cookies::CookieJar.build(
      browser.request, browser.request.cookies,
    ).encrypted[session_key]

    continuity.each { |key, value| assert_equal value, retained[key.to_s], "#{key} remains available for retry" }
    assert_equal session_cookie_value, browser.cookies[sid_cookie]
  end

  teardown do
    %i(
      sign_in_available_app sign_up_available_app
      sign_in_available_com sign_up_available_com
      sign_in_available_org sign_up_available_org
    ).each { |feature| Flipper.enable(feature) }
  end

  SURFACES.each do |surface, host|
    FLOWS.each do |flow|
      test "#{surface} #{flow} sentry redirects to its fixed entry when allowed" do
        host!(host)
        Flipper.enable(FeatureFlags::REGISTRY.fetch(:"#{flow}_available_#{surface}").name)

        entry_name = (flow == :sign_in) ? "in" : "up"
        get "/sign/#{entry_name}/sentry",
            params: { entry_ref: "server-entry-ref", pt: "untrusted-or-signed", ri: "jp" },
            headers: { "Host" => host, "HTTPS" => "on" }

        assert_response :see_other
        location = URI.parse(response.location)

        assert_equal "/sign/#{(flow == :sign_in) ? "in" : "up"}", location.path
        query = Rack::Utils.parse_nested_query(location.query.to_s)

        assert_equal "server-entry-ref", query.fetch("entry_ref")
        assert_nil query["pt"], "an invalid target must not be forwarded"
      end

      test "#{surface} #{flow} sentry refuses without a cacheable response when blocked" do
        host!(host)
        Flipper.disable(FeatureFlags::REGISTRY.fetch(:"#{flow}_available_#{surface}").name)

        entry_name = (flow == :sign_in) ? "in" : "up"
        get "/sign/#{entry_name}/sentry", headers: { "Host" => host, "HTTPS" => "on" }

        assert_response :service_unavailable
        assert_equal "no-store", response.headers["Cache-Control"]
        assert_equal "no-referrer", response.headers["Referrer-Policy"]
        assert_nil response.headers["Retry-After"]
      end

      test "A29-12: #{surface} #{flow} refusal is localized and omits the reason" do
        host!(host)
        Flipper.disable(FeatureFlags::REGISTRY.fetch(:"#{flow}_available_#{surface}").name)
        entry_name = (flow == :sign_in) ? "in" : "up"
        key = (flow == :sign_in) ? "errors.messages.sign_in_unavailable" : "errors.messages.sign_up_unavailable"
        %w(en ja).each do |locale|
          get "/sign/#{entry_name}/sentry",
              params: { ri: "jp", lx: locale }, headers: { "Host" => host, "HTTPS" => "on" }

          assert_response :service_unavailable
          assert_equal I18n.t(key, locale: locale), response.body
          assert_equal "no-store", response.headers["Cache-Control"]
          assert_nil response.headers["Retry-After"]
          assert_not_includes response.body, "sentry_blocked"
        end
      end

      test "A07-3/A29-12: #{surface} #{flow} refusal logs one reason code without request secrets" do
        host!(host)
        Flipper.disable(FeatureFlags::REGISTRY.fetch(:"#{flow}_available_#{surface}").name)
        messages = []

        Rails.logger.stub(:info, ->(*args, &block) { messages << (args.first || block&.call).to_s }) do
          flow_name = (flow == :sign_in) ? "in" : "up"
          get "/sign/#{flow_name}/sentry",
              params: {
                entry_ref: "sensitive-entry-reference",
                token: "sensitive-token-value",
                code: "sensitive-code-value",
                email: "private-contact@example.test",
              }, headers: { "Host" => host, "HTTPS" => "on" }
        end

        refusal_events =
          messages.filter_map do |message|
            parsed = JSON.parse(message)
            parsed if parsed.fetch("event") == "sign.refused"
          rescue JSON::ParserError
            nil
          end

        assert_equal 1, refusal_events.length

        data = refusal_events.fetch(0).fetch("data")

        assert_equal "retryable", data.fetch("refusal_class")
        assert_equal "sentry_blocked", data.fetch("reason_code")
        assert_equal surface.to_s, data.fetch("surface")
        %w(
          entry_ref sensitive-entry-reference sensitive-token-value sensitive-code-value
          private-contact@example.test
        ).each { |secret| assert_not_includes refusal_events.fetch(0).to_json, secret }
      end
    end
  end
end
