# typed: false
# frozen_string_literal: true

require "test_helper"

# Localized customer copy is asserted literally in both supported languages.
class PlainResponseLocalizationTest < ActionDispatch::IntegrationTest
  self.fixture_table_names = []

  setup do
    @previous_protection = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true
    OmniAuth.config.test_mode = true
    TurnstileVerifierStub.enabled = true
    TurnstileVerifierStub.challenge_enabled = true
    TurnstileVerifierStub.challenge_response = { "success" => true }
  end

  teardown do
    ActionController::Base.allow_forgery_protection = @previous_protection
    OmniAuth.config.mock_auth[:google] = nil
    OmniAuth.config.mock_auth[:apple] = nil
    TurnstileVerifierStub.enabled = false
    TurnstileVerifierStub.challenge_enabled = false
    TurnstileVerifierStub.challenge_response = nil
  end

  # Customer-copy fixtures verify rendered translations independently of the locale lookup.
  # rubocop:disable I18n/RailsI18n/DecorateString -- Literal expected translations.
  {
    "en" => ["Please confirm that you want to create a new Umaxica Identity.",
             "This page is out of date. Please reload it and try again.",],
    "ja" => ["新しいUmaxica Identityを作成することを確認してください。",
             "この画面は古くなっています。再読み込みしてから、もう一度お試しください。",],
  }.each do |locale, (expected_confirmation, expected_stale)|
    # rubocop:enable I18n/RailsI18n/DecorateString
    %w(google apple).each do |provider|
      test "#{provider} plain signup refusals use #{locale} without advancing the flow" do
        sign_up = true
        subject = "localized-social-#{SecureRandom.hex(8)}"
        base_host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
        auth_host = ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
        visa_host = ENV.fetch("PUBLIC_VISA_SERVICE_URL")
        base = open_session
        auth = open_session
        visa = open_session
        browsers = { base_host => base, auth_host => auth, visa_host => visa }
        navigation = { "Sec-Fetch-Mode" => "navigate",
                       "Sec-Fetch-Dest" => "document",
                       "Sec-Fetch-Site" => "cross-site", }
        auth_headers = { "Origin" => "https://#{auth_host}", "Sec-Fetch-Site" => "same-origin" }
        base_headers = { "Origin" => "https://#{base_host}", "Sec-Fetch-Site" => "same-origin" }
        base.host!(base_host)
        base.https!
        auth.host!(auth_host)
        auth.https!
        visa.host!(visa_host)
        visa.https!
        base.get(
          "/sign",
          params: { ri: "jp" }, headers: navigation,
        )

        assert_equal 200, base.response.status
        form = base.response.parsed_body.at_css("form")
        fields = form.css("input[name]").to_h { |input| [input["name"], input["value"]] }
        base.post(form["action"], params: fields, headers: base_headers)

        assert_equal 303, base.response.status
        current = base
        20.times do
          if current.response.redirect?
            target = URI.parse(current.response.location)
            if target.host == "jump.umaxica.net"
              payload, = JWT.decode(Rack::Utils.parse_query(target.query).fetch("rt"), nil, false)
              target = URI.parse(payload.fetch("url"))
            end
            target = URI.join("https://#{current.host}", target.to_s)
            current = browsers.fetch(target.host)
            current.get(target.request_uri, headers: navigation)
            next
          end
          form = current.response.parsed_body.at_css(
            "form[id$='continuation-form'], form[id$='confirmation-form'], " \
            "form#oidc-authorization-handoff-form, form#oidc-authorization-exit-form",
          )
          break unless form

          target = URI.join("https://#{current.host}", form["action"])
          fields = form.css("input[name]").to_h { |input| [input["name"], input["value"]] }
          current = browsers.fetch(target.host)
          current.post(
            target.request_uri,
            params: fields,
            headers: { "Origin" => "https://#{target.host}", "Sec-Fetch-Site" => "same-origin" },
          )
        end

        assert_equal [auth, 200, "/sign/in"], [current, current.response.status, current.request.path]
        props = JSON.parse(auth.response.parsed_body.at_css("script[data-page='app']").text).fetch("props")
        form = props.fetch("switch_form")
        auth.post(
          form.fetch("action"),
          params: { to: "sign_up", authenticity_token: form.fetch("authenticity_token") },
          headers: auth_headers,
        )

        assert_equal 303, auth.response.status
        current = auth
        20.times do
          if current.response.redirect?
            target = URI.parse(current.response.location)
            if target.host == "jump.umaxica.net"
              payload, = JWT.decode(Rack::Utils.parse_query(target.query).fetch("rt"), nil, false)
              target = URI.parse(payload.fetch("url"))
            end
            target = URI.join("https://#{current.host}", target.to_s)
            current = browsers.fetch(target.host)
            current.get(target.request_uri, headers: navigation)
            next
          end
          form = current.response.parsed_body.at_css(
            "form[id$='continuation-form'], form[id$='confirmation-form'], " \
            "form#oidc-authorization-handoff-form, form#oidc-authorization-exit-form",
          )
          break unless form

          target = URI.join("https://#{current.host}", form["action"])
          fields = form.css("input[name]").to_h { |input| [input["name"], input["value"]] }
          current = browsers.fetch(target.host)
          current.post(
            target.request_uri,
            params: fields,
            headers: { "Origin" => "https://#{target.host}", "Sec-Fetch-Site" => "same-origin" },
          )
        end

        assert_equal [auth, 200, "/sign/up"], [current, current.response.status, current.request.path]
        binding = ClientAuthAdmissionBinding.find_by!(
          admitted_auth_ceremony_session_id:
            ClientAuthCeremonySession.find_active_by_raw_sid(auth.cookies["auth_sid"]).id,
        )
        ClientOidcAuthorizationTransaction.find(binding.authorization_transaction_id)
        ClientAuthCeremonySession.find(binding.admitted_auth_ceremony_session_id)
        csrf = auth.response.parsed_body.at_css('meta[name="csrf-token"]')["content"]
        auth.post(
          "/social/#{provider}/#{sign_up ? "registration" : "session"}",
          params: { ri: "jp" },
          headers: auth_headers.merge("X-CSRF-Token" => csrf),
        )

        assert_equal 307, auth.response.status
        state = auth.session.fetch(SocialCallbackGuard::SOCIAL_STATE_SESSION_KEY)
        OmniAuth.config.mock_auth[provider.to_sym] = OmniAuth::AuthHash.new(
          provider: provider, uid: subject, info: { name: "SOC provider fixture" },
          credentials: { token: "provider-fixture", expires_at: 1.hour.from_now.to_i },
          extra: { id_info: { nonce: auth.session[:social_auth_nonce] } },
        )
        auth.get("/social/#{provider}/callback", params: { state: state, ri: "jp" }, headers: auth_headers)

        assert_equal 302, auth.response.status
        2.times { auth.follow_redirect!(headers: navigation) }

        assert_equal 200, auth.response.status
        flow = ClientSignUpFlow.find_by!(auth_admission_binding_id: binding.id)
        props = JSON.parse(auth.response.parsed_body.at_css("script[data-page='app']").text).fetch("props")
        confirmation_action = props.fetch("action")
        snapshot = flow.reload.attributes
        [nil, "", "0", "false"].each do |confirmation|
          assert_no_difference(["Client.count", "ClientExternalIdentity.count", "ClientToken.count"]) do
            auth.patch(
              confirmation_action, params: { lx: locale,
                                             confirm_new_social_identity: confirmation,
                                             checkpoint_version: flow.checkpoint_version, },
                                   headers: auth_headers.merge("X-CSRF-Token" => csrf),
            )
          end
          assert_equal 422, auth.response.status
          assert_equal expected_confirmation, auth.response.body
          assert_equal snapshot, flow.reload.attributes
        end
        auth.patch(
          confirmation_action,
          params: { :confirm_new_social_identity => "1",
                    :checkpoint_version => flow.checkpoint_version,
                    "cf-turnstile-response" => "fixture", },
          headers: auth_headers.merge("X-CSRF-Token" => csrf),
        )

        assert_equal 302, auth.response.status
        auth.response.location
        3.times do
          break unless auth.response.redirect?

          auth.follow_redirect!(headers: navigation)
        end

        assert_equal 200, auth.response.status
        assert_equal "/sign/up/check/#{provider}/birthdate", auth.request.path
        birthdate_action = auth.request.fullpath
        csrf = auth.response.parsed_body.at_css('meta[name="csrf-token"]')["content"]
        snapshot = flow.reload.attributes
        [nil, "", "not-a-number", flow.checkpoint_version - 1, flow.checkpoint_version + 1].each do |version|
          assert_no_difference(["Client.count", "ClientExternalIdentity.count", "ClientToken.count"]) do
            auth.patch(
              birthdate_action, params: { lx: locale,
                                          requirement: "birthdate",
                                          birthdate: "2000-01-01",
                                          checkpoint_version: version, },
                                headers: auth_headers.merge("X-CSRF-Token" => csrf),
            )
          end
          assert_equal 409, auth.response.status
          assert_equal expected_stale, auth.response.body
          assert_equal snapshot, flow.reload.attributes
        end
      end
    end
  end
end
