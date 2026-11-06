# typed: false
# frozen_string_literal: true

require "test_helper"

# Provider fixtures exercise the application contract, not live Google or Apple behavior.
class SocialLoginSocTest < ActionDispatch::IntegrationTest
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

  %w(google apple).each do |provider|
    if provider == "apple"
      test "SOC-5: Apple linked reserved Client is refused without guidance or authority" do
        sign_up = false
        subject = "soc5-#{SecureRandom.hex(8)}"
        actor = Client.create!(
          security_mode_id: SecurityModeConfigurable::NORMAL,
          status_id: ClientStatus::RESERVED, birthdate: "2000-01-01",
        )
        ClientAppleIdentity.create!(
          user: actor, uid: subject, provider: "apple", status_id: ClientAppleIdentityStatus::ACTIVE,
        )
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
        binding = ClientAuthAdmissionBinding.find_by!(
          admitted_auth_ceremony_session_id:
            ClientAuthCeremonySession.find_active_by_raw_sid(auth.cookies["auth_sid"]).id,
        )
        transaction = ClientOidcAuthorizationTransaction.find(binding.authorization_transaction_id)
        ceremony = ClientAuthCeremonySession.find(binding.admitted_auth_ceremony_session_id)
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
        assert_no_difference(
          ["Client.count", "ClientExternalIdentity.count", "ClientSignUpFlow.count",
           "ClientToken.count",],
        ) do
          auth.get("/social/#{provider}/callback", params: { state: state, ri: "jp" }, headers: auth_headers)
        end
        assert_equal [403, nil], [auth.response.status, auth.response.location]
        assert_not_predicate ceremony.reload, :authentication_evidence_recorded?
        assert_equal "pending", transaction.reload.status_name
        assert_equal [nil, nil], [auth.cookies[AuthenticationBase::ACCESS_COOKIE_KEY],
                                  auth.cookies[AuthenticationBase::REFRESH_COOKIE_KEY],]
      end

    end

    [false, true].each do |sign_up|
      test "SOC-6: #{provider} unfinished registration is refused at #{sign_up ? "signup" : "signin"}" do
        subject = "soc6-#{SecureRandom.hex(8)}"
        actor = Client.create!(
          security_mode_id: SecurityModeConfigurable::NORMAL,
          status_id: ClientStatus::UNVERIFIED_WITH_SIGN_UP, birthdate: "2000-01-01",
        )
        case provider
        when "google"
          ClientGoogleIdentity.create!(
            user: actor, uid: subject, provider: provider, status_id: ClientGoogleIdentityStatus::ACTIVE,
          )
        when "apple"
          ClientAppleIdentity.create!(
            user: actor, uid: subject, provider: provider, status_id: ClientAppleIdentityStatus::ACTIVE,
          )
        end
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
        if sign_up
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
        end
        binding = ClientAuthAdmissionBinding.find_by!(
          admitted_auth_ceremony_session_id:
            ClientAuthCeremonySession.find_active_by_raw_sid(auth.cookies["auth_sid"]).id,
        )
        transaction = ClientOidcAuthorizationTransaction.find(binding.authorization_transaction_id)
        ceremony = ClientAuthCeremonySession.find(binding.admitted_auth_ceremony_session_id)
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
        assert_no_difference(
          ["Client.count", "ClientExternalIdentity.count", "ClientSignUpFlow.count",
           "ClientToken.count",],
        ) do
          auth.get("/social/#{provider}/callback", params: { state: state, ri: "jp" }, headers: auth_headers)
        end
        assert_equal [400, nil], [auth.response.status, auth.response.location]
        assert_not_predicate ceremony.reload, :authentication_evidence_recorded?
        assert_equal "pending", transaction.reload.status_name
        assert_equal [nil, nil], [auth.cookies[AuthenticationBase::ACCESS_COOKIE_KEY],
                                  auth.cookies[AuthenticationBase::REFRESH_COOKIE_KEY],]
      end

      test "SOC-8: #{provider} abandoned #{sign_up ? "signup" : "signin"} permits two fresh browser entries" do
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
        # Owner decision: each fresh admission must reach the first page with 200 after abandonment.
        parent_ids = []
        3.times do |attempt|
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
          if sign_up
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

                headers: { "Origin" => "https://#{target.host}",
                           "Sec-Fetch-Site" => "same-origin", },
              )
            end

            assert_equal [auth, 200, "/sign/up"], [current, current.response.status, current.request.path]
          end
          binding = ClientAuthAdmissionBinding.find_by!(
            admitted_auth_ceremony_session_id:
              ClientAuthCeremonySession.find_active_by_raw_sid(auth.cookies["auth_sid"]).id,
          )
          transaction = ClientOidcAuthorizationTransaction.find(binding.authorization_transaction_id)
          ceremony = ClientAuthCeremonySession.find(binding.admitted_auth_ceremony_session_id)
          csrf = auth.response.parsed_body.at_css('meta[name="csrf-token"]')["content"]
          parent_ids << transaction.id

          assert_equal attempt + 1, parent_ids.uniq.size
          assert_no_difference(
            ["Client.count", "ClientExternalIdentity.count", "ClientSignUpFlow.count",
             "ClientToken.count",],
          ) do
            auth.post(
              "/social/#{provider}/#{sign_up ? "registration" : "session"}",
              params: { ri: "jp" },

              headers: auth_headers.merge("X-CSRF-Token" => csrf),
            )
          end
          assert_equal 307, auth.response.status
          assert_not_predicate ceremony.reload, :authentication_evidence_recorded?
        end
      end
    end

    test "SOC-9: #{provider} provider refusal ends the attempt without authority" do
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
      transaction = ClientOidcAuthorizationTransaction.find(binding.authorization_transaction_id)
      ceremony = ClientAuthCeremonySession.find(binding.admitted_auth_ceremony_session_id)
      csrf = auth.response.parsed_body.at_css('meta[name="csrf-token"]')["content"]
      auth.post(
        "/social/#{provider}/registration",
        params: { ri: "jp" },
        headers: auth_headers.merge("X-CSRF-Token" => csrf),
      )

      assert_equal 307, auth.response.status
      assert_no_difference(
        ["Client.count", "ClientExternalIdentity.count", "ClientSignUpFlow.count",
         "ClientToken.count",],
      ) do
        auth.get("/social/failure", params: { message: "access_denied", strategy: provider }, headers: auth_headers)
      end
      assert_equal [400, nil], [auth.response.status, auth.response.location]
      assert_nil auth.session[SocialCallbackGuard::SOCIAL_STATE_SESSION_KEY]
      assert_predicate auth.cookies["auth_sid"].to_s, :empty?
      assert_not_predicate ceremony.reload, :authentication_evidence_recorded?
      assert_equal "pending", transaction.reload.status_name
    end

    %w(confirmation birthdate).each do |step|
      next if provider == "apple" && step == "confirmation"

      test "SOC-10: #{provider} cancellation at #{step} ends its parent once and returns to RP" do
        sign_up = true
        subject = "soc10-#{SecureRandom.hex(8)}"
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
        transaction = ClientOidcAuthorizationTransaction.find(binding.authorization_transaction_id)
        ceremony = ClientAuthCeremonySession.find(binding.admitted_auth_ceremony_session_id)
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
        cancel_action = confirmation_action
        if step == "birthdate"
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
          cancel_action = birthdate_action
        end
        assert_no_difference(["Client.count", "ClientExternalIdentity.count", "ClientToken.count"]) do
          auth.delete(
            cancel_action, params: { checkpoint_version: flow.reload.checkpoint_version },
                           headers: auth_headers.merge("X-CSRF-Token" => csrf),
          )
        end
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

        assert_equal base, current
        assert_predicate transaction.reload, :canceled?
        assert_predicate ceremony.reload, :cancelled?
        assert_not_predicate flow.reload, :completed?
        assert_equal 0, ClientExternalIdentity.where(provider: provider, subject: subject).count
        assert_equal [nil, nil], [base.cookies[OidcRpBrowserCredentialContract::ACCESS_COOKIE],
                                  base.cookies[OidcRpBrowserCredentialContract::REFRESH_COOKIE],]
        terminal_state = [transaction.attributes, ceremony.attributes, flow.attributes]
        auth.delete(
          cancel_action, params: { checkpoint_version: flow.checkpoint_version },
                         headers: auth_headers.merge("X-CSRF-Token" => csrf),
        )

        assert_operator auth.response.status, :>=, 400
        assert_operator auth.response.status, :<, 500
        assert_equal terminal_state, [transaction.reload.attributes, ceremony.reload.attributes, flow.reload.attributes]
      end
    end

    %w(first confirmation).each do |earlier|
      test "SOC-11: #{provider} GET of #{earlier} page after advancing preserves all state" do
        sign_up = true
        subject = "soc11-#{SecureRandom.hex(8)}"
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
        transaction = ClientOidcAuthorizationTransaction.find(binding.authorization_transaction_id)
        ceremony = ClientAuthCeremonySession.find(binding.admitted_auth_ceremony_session_id)
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
        if earlier == "confirmation"
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
          auth.request.fullpath
          auth.response.parsed_body.at_css('meta[name="csrf-token"]')["content"]
        end
        snapshot = [flow.reload.attributes, ceremony.reload.attributes, transaction.reload.attributes]
        assert_no_difference(["Client.count", "ClientExternalIdentity.count", "ClientToken.count"]) do
          auth.get((earlier == "first") ? "/sign/up?ri=jp" : confirmation_action, headers: navigation)
        end
        assert_equal 409, auth.response.status
        cookie_names =
          Array(auth.response.headers["Set-Cookie"]).flat_map { |header|
            header.split(
              "
      ",
            )
          }.map { |header| header.split("=", 2).first }

        assert_empty cookie_names & ["auth_sid", Rails.application.config.session_options.fetch(:key),
                                     AuthenticationBase::ACCESS_COOKIE_KEY, AuthenticationBase::REFRESH_COOKIE_KEY,]
        assert_equal snapshot, [flow.reload.attributes, ceremony.reload.attributes, transaction.reload.attributes]
      end
    end

    [false, true].each do |sign_up|
      test "SOC-12: #{provider} #{sign_up ? "signup" : "signin"} replay creates no second account or session" do
        subject = "soc12-#{SecureRandom.hex(8)}"
        unless sign_up
          actor = Client.create!(
            security_mode_id: SecurityModeConfigurable::NORMAL,
            status_id: ClientStatus::ACTIVE, birthdate: "2000-01-01",
          )
          case provider
          when "google"
            ClientGoogleIdentity.create!(
              user: actor, uid: subject, provider: provider, status_id: ClientGoogleIdentityStatus::ACTIVE,
            )
          when "apple"
            ClientAppleIdentity.create!(
              user: actor, uid: subject, provider: provider, status_id: ClientAppleIdentityStatus::ACTIVE,
            )
          end
        end
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
        if sign_up
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
        end
        binding = ClientAuthAdmissionBinding.find_by!(
          admitted_auth_ceremony_session_id:
            ClientAuthCeremonySession.find_active_by_raw_sid(auth.cookies["auth_sid"]).id,
        )
        transaction = ClientOidcAuthorizationTransaction.find(binding.authorization_transaction_id)
        ceremony = ClientAuthCeremonySession.find(binding.admitted_auth_ceremony_session_id)
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

        assert_equal(sign_up ? 302 : 303, auth.response.status)
        snapshot = [ceremony.reload.attributes, transaction.reload.attributes]
        assert_no_difference(
          ["Client.count", "ClientExternalIdentity.count", "ClientSignUpFlow.count",
           "ClientToken.count",],
        ) do
          auth.get("/social/#{provider}/callback", params: { state: state, ri: "jp" }, headers: auth_headers)
        end
        assert_equal 403, auth.response.status
        assert_equal snapshot, [ceremony.reload.attributes, transaction.reload.attributes]
        assert_equal [nil, nil], [auth.cookies[AuthenticationBase::ACCESS_COOKIE_KEY],
                                  auth.cookies[AuthenticationBase::REFRESH_COOKIE_KEY],]
      end
    end

    test "SOC-13: #{provider} registered signup guidance starts a fresh signin that reaches Base Dashboard" do
      sign_up = true
      subject = "soc13-#{SecureRandom.hex(8)}"
      actor = Client.create!(
        security_mode_id: SecurityModeConfigurable::NORMAL,
        status_id: ClientStatus::ACTIVE, birthdate: "2000-01-01",
      )
      case provider
      when "google"
        ClientGoogleIdentity.create!(
          user: actor, uid: subject, provider: provider, status_id: ClientGoogleIdentityStatus::ACTIVE,
        )
      when "apple"
        ClientAppleIdentity.create!(
          user: actor, uid: subject, provider: provider, status_id: ClientAppleIdentityStatus::ACTIVE,
        )
      end
      BaseSelectorBootstrapAuthority.call(surface: :app, principal: actor)
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
      transaction = ClientOidcAuthorizationTransaction.find(binding.authorization_transaction_id)
      ceremony = ClientAuthCeremonySession.find(binding.admitted_auth_ceremony_session_id)
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

      assert_equal 400, auth.response.status
      link = auth.response.parsed_body.at_css("main a")

      assert link
      fresh = URI.parse(link["href"])

      assert_equal [base_host, "/sign"], [fresh.host, fresh.path]
      old_binding = binding
      old_transaction = transaction
      old_ceremony = ceremony
      old_snapshot = [old_binding.reload.attributes, old_transaction.reload.attributes, old_ceremony.reload.attributes]
      base.get(fresh.request_uri, headers: navigation)

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
      binding = ClientAuthAdmissionBinding.find_by!(
        admitted_auth_ceremony_session_id:
          ClientAuthCeremonySession.find_active_by_raw_sid(auth.cookies["auth_sid"]).id,
      )
      transaction = ClientOidcAuthorizationTransaction.find(binding.authorization_transaction_id)
      ceremony = ClientAuthCeremonySession.find(binding.admitted_auth_ceremony_session_id)
      csrf = auth.response.parsed_body.at_css('meta[name="csrf-token"]')["content"]

      assert_not_equal old_binding.id, binding.id
      assert_not_equal old_transaction.id, transaction.id
      sign_up = false
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
      assert_no_difference(
        ["Client.count", "ClientExternalIdentity.count", "ClientSignUpFlow.count",
         "ClientToken.count",],
      ) do
        auth.get("/social/#{provider}/callback", params: { state: state, ri: "jp" }, headers: auth_headers)
      end
      assert_equal 303, auth.response.status
      assert_predicate ceremony.reload, :authentication_evidence_recorded?
      assert_equal provider, ceremony.authentication_method

      # Replace network transport only; Visa protocol and Base client JWKS use real endpoints.
      protocol = open_session
      protocol.host!(visa_host)
      protocol.https!
      transport =
        Faraday::Adapter::Test::Stubs.new do |stub|
          stub.post(/.*/) do |env|
            assert_equal [visa_host, "/oauth/token"], [env.url.host, env.url.path]
            executor_key = Rails.application.executor.active_key
            outer_execution = ActiveSupport::IsolatedExecutionState.delete(executor_key)
            begin
              protocol.host!(env.url.authority)
              protocol.https!(env.url.scheme == "https")
              protocol.post(
                env.url.request_uri, params: Rack::Utils.parse_query(env.body),
                                     headers: { "Accept" => "application/json" },
              )
            ensure
              ActiveSupport::IsolatedExecutionState[executor_key] = outer_execution
            end

            assert_equal 200, protocol.response.status,
                         protocol.response.parsed_body.slice("error", "error_description").inspect
            [protocol.response.status, { "Content-Type" => "application/json" }, protocol.response.body]
          end
          stub.get(/.*/) do |env|
            get_browser = open_session

            assert_includes [visa_host, base_host], env.url.host
            assert_includes(
              ["/.well-known/jwks.json", "/oauth/userinfo", "/api/v0/avatar/app/dashboard-identity"], env.url.path,
            )
            executor_key = Rails.application.executor.active_key
            outer_execution = ActiveSupport::IsolatedExecutionState.delete(executor_key)
            begin
              headers = { "Accept" => "application/json" }
              if env.request_headers["X-Client-Assertion"].present?
                headers["X-Client-Assertion"] = env.request_headers["X-Client-Assertion"]
              end
              headers["Authorization"] =
                env.request_headers["Authorization"] if env.request_headers["Authorization"].present?
              get_browser.host!(env.url.authority)
              get_browser.https!(env.url.scheme == "https")
              get_browser.get(env.url.request_uri, headers: headers)
            ensure
              ActiveSupport::IsolatedExecutionState[executor_key] = outer_execution
            end

            assert_equal 200, get_browser.response.status,
                         get_browser.response.parsed_body.slice("error", "error_description").inspect
            [get_browser.response.status, { "Content-Type" => "application/json" }, get_browser.response.body]
          end
        end
      connection =
        Faraday.new do |builder|
          builder.request(:url_encoded)
          builder.adapter(:test, transport)
        end
      previous_transport_permission = TestSupport::OutboundHttpGuard::ALLOWED.value
      begin
        TestSupport::OutboundHttpGuard::ALLOWED.value = true
        OutboundHttp::Connection.stub(
          :build, ->(**options) {
                    assert_includes [visa_host, base_host], URI.parse(options.fetch(:url).to_s).host
                    connection
                  },
        ) do
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
        end
      ensure
        TestSupport::OutboundHttpGuard::ALLOWED.value = previous_transport_permission
      end

      assert_equal [base, 200, "/dashboard"], [current, base.response.status, base.request.path]
      assert_predicate base.cookies[OidcRpBrowserCredentialContract::ACCESS_COOKIE], :present?
      assert_predicate base.cookies[OidcRpBrowserCredentialContract::REFRESH_COOKIE], :present?
      assert_equal 1, ClientToken.where(user_id: actor.id).count
      assert_equal "consumed", transaction.reload.status_name
      assert_equal old_snapshot,
                   [old_binding.reload.attributes, old_transaction.reload.attributes, old_ceremony.reload.attributes]
    end
  end
end
