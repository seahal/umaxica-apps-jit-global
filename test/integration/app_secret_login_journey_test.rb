# frozen_string_literal: true

require "test_helper"
require "webauthn/fake_client"

class AppSecretLoginJourneyTest < ActionDispatch::IntegrationTest
  SECRET_LIFETIME_VALUES = {
    "APP_SECRET_ISSUANCE_TTL_SECONDS" => "600",
    "APP_SECRET_PURGE_DELAY_SECONDS" => "86400",
    "APP_SECRET_OUTBOX_RETENTION_SECONDS" => "604800",
    "APP_SECRET_PROOF_RETENTION_SECONDS" => "2592000",
  }.freeze

  setup do
    @previous_forgery_protection = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true
    @previous_lifetimes = ENV.to_h.slice(*SECRET_LIFETIME_VALUES.keys)
    SECRET_LIFETIME_VALUES.each { |key, value| ENV[key] = value }
    TurnstileVerifierStub.enabled = true
    TurnstileVerifierStub.response = { "success" => true }
    TurnstileVerifierStub.challenge_enabled = true
    TurnstileVerifierStub.challenge_response = { "success" => true }
  end

  teardown do
    ActionController::Base.allow_forgery_protection = @previous_forgery_protection
    SECRET_LIFETIME_VALUES.each_key do |key|
      @previous_lifetimes.key?(key) ? ENV[key] = @previous_lifetimes.fetch(key) : ENV.delete(key)
    end
    TurnstileVerifierStub.enabled = false
    TurnstileVerifierStub.response = nil
    TurnstileVerifierStub.challenge_enabled = false
    TurnstileVerifierStub.challenge_response = nil
  end

  (0..20).each do |active_count|
    test "signed-in Passkey registration distributes correctly at A=#{active_count}" do
      auth_host = ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
      base_host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
      actor = Client.create!(status_id: ClientStatus::ACTIVE)
      token = ClientToken.create!(
        user: actor, established_authentication_method: "secret", root_login_established_at: ClientToken.database_now,
      )
      BaseSelectorBootstrapAuthority.call(surface: :app, principal: actor)
      BaseSelectorAuthority.prepare(surface: :app, principal: actor, session: token)
      token.update!(
        last_step_up_at: ClientToken.database_now, last_step_up_scope: "settings_passkey",
        last_step_up_method: "passkey", last_step_up_session_public_id: token.public_id,
        last_step_up_purpose: "step_up", last_step_up_audience: "step_up:app",
        last_step_up_phishing_resistant: true, last_step_up_user_verified: true,
        last_step_up_credential_ref: "test-step-up", last_step_up_full_reauthentication: false,
      )
      now = Client.database_now
      active_count.times do
        prior = ClientSecretIssuance.create!(
          client: actor, origin: "manual", origin_operation_id: SecureRandom.uuid,
          attempt_number: 1, browser_session_ref: token.public_id, planned_count: 1,
          expires_at: now + 1.minute, presented_at: now, confirmed_at: now,
        )
        raw = SecureRandom.base58(32)
        ClientSecretCredential.create!(
          client: actor, issuance: prior, name: "Existing", password: raw,
          confirmed_at: now,
        )
      end
      base = open_session
      base.host!(base_host)
      base.https!
      begin
        fv5342 = base
        fv5345 = actor
        fv5226 = token
        fv5340 = base_host
        fv5344 = OidcClientRegistry.find!("base-app-ww")
        fv5346 = ClientRpSession.database_now
        fv5341 = ClientRpSession.create!(
          client_token: fv5226,
          oidc_client_id: fv5344.client_id,
          oidc_scope: "openid profile",
          oidc_jti: SecureRandom.uuid,
          oidc_nonce: SecureRandom.hex(16),
          oidc_auth_time: fv5226.root_login_established_at || fv5346,
          refresh_token_expires_at: fv5346 + 30.minutes,
        )
        fv5343 = AuthenticationTokenService.encode(
          fv5345,
          host: fv5340,
          resource_type: "client",
          session_public_id: fv5226.public_id,
          base_session_public_id: fv5226.public_id,
          oidc_sid: fv5341.public_id,
          oidc_jti: fv5341.oidc_jti,
          expires_at: fv5346 + 10.minutes,
          scopes: %w(openid profile),
          issuer: OidcIssuer.for_client(fv5344),
          audiences: [fv5344.aud],
          jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(fv5344),
          subject: OidcSubject.for(fv5345, resource_type: "client"),
          client_id: fv5344.client_id,
        )
        fv5342.cookies[OidcRpBrowserCredentialContract::ACCESS_COOKIE] =
          fv5343
        fv5342.cookies.merge(
          "#{OidcRpBrowserCredentialContract::REFRESH_COOKIE}=#{Rack::Utils.escape(fv5341.issue_refresh_token!)}",
          URI.parse("https://#{fv5340}/"),
        )
      end
      base_headers = begin
        rp_headers = as_user_headers(actor, host: base_host, session_public_id: token.public_id)
        rp_host = rp_headers["Host"]
        rp_route =
          begin
            Rails.application.routes.recognize_path("https://#{rp_host}/") if rp_host.present?
          rescue ActionController::RoutingError
            nil
          end
        rp_family, rp_surface = rp_route&.fetch(:controller)&.split("/")
        if %w(base warp core edit).include?(rp_family) && rp_surface == "app"
          rp_client_id =
            case rp_family
            when "base" then "base-#{rp_surface}-ww"
            when "edit" then "edit-org"
            else "#{rp_family}-#{rp_surface}"
            end
          rp_token = ClientToken.find_by!(public_id: rp_headers.fetch("X-TEST-SESSION-PUBLIC-ID"))
          rp_client = OidcClientRegistry.find!(rp_client_id)
          rp_key = [rp_client.client_id, rp_token.public_id]
          @base_browser_rp_credentials ||= {}
          if !@base_browser_rp_credentials[rp_key] && rp_token.currently_usable? &&
              !(rp_token.device_session_id && ClientRpSession.exists?(
                device_session_id: rp_token.device_session_id, oidc_client_id: rp_client.client_id, revoked_at: nil,
              ))
            rp_token.rotate_refresh_token! unless rp_token.device_session.current_refresh_token_id
            rp_now = Time.current
            rp_session = ClientRpSession.create!(
              client_token: rp_token, oidc_client_id: rp_client.client_id, oidc_scope: "openid profile",
              oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16), oidc_auth_time: rp_now,
              refresh_token_expires_at: rp_now + 10.minutes,
            )
            rp_access = AuthenticationTokenService.encode(
              rp_token.user, host: rp_host, resource_type: "client",
                             session_public_id: rp_token.public_id, base_session_public_id: rp_token.public_id,
                             oidc_sid: rp_session.public_id, oidc_jti: rp_session.oidc_jti,
                             expires_at: rp_now + 10.minutes, scopes: %w(openid profile),
                             issuer: OidcIssuer.for_client(rp_client), audiences: [rp_client.aud],
                             jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(rp_client),
                             subject: OidcSubject.for(
                               rp_token.user,
                               resource_type: "client",
                             ), client_id: rp_client.client_id,
            )
            @base_browser_rp_credentials[rp_key] = [rp_access, rp_session.issue_refresh_token!]
          end
          if @base_browser_rp_credentials[rp_key]
            rp_access, rp_refresh = @base_browser_rp_credentials.fetch(rp_key)
            rp_cookie = [
              rp_headers.fetch("Cookie"),
              "#{OidcRpBrowserCredentialContract::ACCESS_COOKIE}=#{Rack::Utils.escape(rp_access)}",
              "#{OidcRpBrowserCredentialContract::REFRESH_COOKIE}=#{Rack::Utils.escape(rp_refresh)}",
            ].join("; ")
            rp_headers = rp_headers.merge("Cookie" => rp_cookie, "HTTP_COOKIE" => rp_cookie)
          end
        end
        rp_headers
      end
        .except("Cookie", "HTTP_COOKIE").merge(
          "Origin" => "https://#{base_host}", "Sec-Fetch-Site" => "same-origin",
        )
      root_access_token = base_headers.fetch("Authorization").delete_prefix("Bearer ")
      installed_root = base.cookies.merge(
        "#{AuthenticationBase::ACCESS_COOKIE_KEY}=#{Rack::Utils.escape(root_access_token)}",
        URI.parse("https://#{base_host}/"),
      )

      base.get(new_base_app_identity_passkey_path(ri: "jp"), headers: base_headers)

      assert_equal [["#{AuthenticationBase::ACCESS_COOKIE_KEY}=#{Rack::Utils.escape(root_access_token)}"], 200],
                   [installed_root, base.response.status]
      csrf = base.response.parsed_body.at_css('input[name="authenticity_token"]')["value"]
      base.post(base_app_identity_passkeys_path(ri: "jp"), params: { authenticity_token: csrf }, headers: base_headers)

      assert_equal 303, base.response.status, base.response.body
      begin
        fv5334 = base
        fv5336 = JitSessionCookieConfig.cookie_key(force_secure: JitSessionCookieConfig.force_secure?)
        fv5335 = fv5334.response.cookies[fv5336]
        if fv5335.nil?
          fv5339 = fv5334.response.headers["Set-Cookie"] || fv5334.response.headers["set-cookie"]
          fv5338 =
            if fv5339.is_a?(String) && fv5339.start_with?("[")
              JSON.parse(fv5339)
            else
              Array(fv5339)
            end
          fv5337 =
            fv5338.flat_map { |entry| entry.to_s.split("\n") }.find do |entry|
              entry.split(";", 2).first.to_s.start_with?("#{fv5336}=")
            end
          if fv5337

            _, fv5335 = fv5337.split(";", 2).first.to_s.split("=", 2)
            fv5335 = Rack::Utils.unescape(fv5335.to_s)
          end
        end

        unless fv5335.nil?
          fv5334.cookies.delete(fv5336)
          # Rack::Test's []= uses its default host. The current request may target a
          # different surface, so install the cookie against the browser's active host.
          fv5334.cookies.merge(
            "#{fv5336}=#{Rack::Utils.escape(fv5335)}",
            URI.parse("https://#{fv5334.host}/"),
          )
        end
      end
      registration_uri = URI.parse(base.response.location)

      assert_equal auth_host, registration_uri.host
      entry_ref = Rack::Utils.parse_query(registration_uri.query).fetch("entry_ref")
      admission_binding = BaseAuthAdmissionCoordinator.find_admission_binding!(surface: "app", reference: entry_ref)

      assert_equal admission_binding.base_browser_digest,
                   AuthAdmissionBinding.browser_digest(
                     surface: "app", entry_ref: entry_ref,
                     nonce: base.session[BaseAdmissionBrowserBinding::BROWSER_NONCE_SESSION_KEY],
                   )
      browser = open_session
      browser.host!(auth_host)
      browser.https!
      auth_headers = {
        "Host" => auth_host, "Origin" => "https://#{auth_host}", "Sec-Fetch-Site" => "same-origin",
      }
      begin
        fv5333 = browser
        fv5332 = registration_uri.path
        fv5331 = entry_ref
        fv5330 = :entry_ref
        fv5329 = { ri: "jp" }
        fv5328 = auth_headers
        fv5327 = true
        fv5326 = base
        begin
          fv5275 = fv5333
          fv5282 = fv5332
          fv5324 = fv5331
          fv5325 = fv5330
          fv5291 = fv5329
          fv5284 = fv5328
          fv5312 = fv5327
          fv5311 = fv5326
          fv5287 = nil
          fv5281 = fv5291.merge(fv5325 => fv5324)
          fv5275.get(fv5282, params: fv5281, headers: fv5284)
          fv5318 =
            begin
              fv5323 = fv5275.response.body
              fv5322 = true
              fv5321 = Nokogiri::HTML(fv5323).at_css("form")
              if fv5321.nil? && fv5322
                nil
              else
                raise RuntimeError, "Auth continuation form is missing" unless fv5321

                fv5320 = fv5321.at_css("input[name='authenticity_token']")&.[]("value")
                raise RuntimeError,
                      "Auth continuation is missing its CSRF token" if fv5320.blank?

                fv5319 = fv5321.css("input[type='hidden']").to_h do |input|
                  [input["name"], input["value"]]
                end.except("authenticity_token")
                [fv5321["action"], fv5320, fv5319]
              end
            end
          if fv5318

            fv5317, fv5315, fv5316 = fv5318

            fv5275.session[BaseAdmissionBrowserBinding::BROWSER_NONCE_SESSION_KEY] ||=
              "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn"
            fv5275.post(
              fv5317,
              params: fv5316.merge(authenticity_token: fv5315),
              headers: fv5284,
            )
            fv5314 = fv5275.response.location
            if fv5314.present?

              fv5310 = URI.parse(fv5314)
              fv5309 = fv5310.host
              fv5286 =
                begin
                  fv5313 = fv5309
                  {
                    ENV.fetch("PUBLIC_BASE_SERVICE_URL") => "app",
                    ENV.fetch("PUBLIC_BASE_CORPORATE_URL") => "com",
                    ENV.fetch("PUBLIC_BASE_STAFF_URL") => "org",
                  }.fetch(fv5313)
                end
              fv5285 = BaseAuthAdmissionCoordinator.find_admission_binding_by_confirmation!(
                surface: fv5286, reference: fv5310.path.split("/").fetch(-2),
              )

              if fv5312
                fv5293 = fv5311 || fv5275
                fv5293.host!(fv5309)
                fv5293.https!
                fv5293.session[BaseAdmissionBrowserBinding::BROWSER_NONCE_SESSION_KEY] ||=
                  "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn"
                fv5308 = fv5310.request_uri
                fv5299 = fv5284.merge(
                  "Host" => fv5309,
                  "Origin" => "https://#{fv5309}",
                  "Sec-Fetch-Site" => "same-origin",
                )
                fv5293.get(fv5308, headers: fv5299)
                fv5302, fv5300, fv5301 =
                  begin
                    fv5307 = fv5293.response.body
                    fv5306 = false
                    fv5305 = Nokogiri::HTML(fv5307).at_css("form")
                    if fv5305.nil? && fv5306
                      nil
                    else
                      raise RuntimeError, "Auth continuation form is missing" unless fv5305

                      fv5304 = fv5305.at_css("input[name='authenticity_token']")&.[]("value")
                      raise RuntimeError,
                            "Auth continuation is missing its CSRF token" if fv5304.blank?

                      fv5303 = fv5305.css("input[type='hidden']").to_h do |input|
                        [input["name"], input["value"]]
                      end.except("authenticity_token")
                      [fv5305["action"], fv5304, fv5303]
                    end
                  end
                fv5293.post(
                  fv5302,
                  params: fv5301.merge(authenticity_token: fv5300),
                  headers: fv5299,
                )
                begin
                  fv5265 = fv5293
                  fv5295 = "session"
                  fv5294 = fv5265.response.cookies[fv5295]
                  if fv5294.nil?
                    fv5298 = fv5265.response.headers["Set-Cookie"] || fv5265.response.headers["set-cookie"]
                    fv5297 =
                      if fv5298.is_a?(String) && fv5298.start_with?("[")
                        JSON.parse(fv5298)
                      else
                        Array(fv5298)
                      end
                    fv5296 =
                      fv5297.flat_map { |entry| entry.to_s.split("\n") }.find do |entry|
                        entry.split(";", 2).first.to_s.start_with?("#{fv5295}=")
                      end
                    if fv5296

                      _, fv5294 = fv5296.split(";", 2).first.to_s.split("=", 2)
                      fv5294 = Rack::Utils.unescape(fv5294.to_s)
                    end
                  end

                  unless fv5294.nil?
                    fv5265.cookies.delete(fv5295)
                    # Rack::Test's []= uses its default host. The current request may target a
                    # different surface, so install the cookie against the browser's active host.
                    fv5265.cookies.merge(
                      "#{fv5295}=#{Rack::Utils.escape(fv5294)}",
                      URI.parse("https://#{fv5265.host}/"),
                    )
                  end
                end
                fv5292 = fv5293.response.location
                raise RuntimeError, "Base confirmation did not return to Auth" if fv5292.blank?

                fv5289 = URI.parse(fv5292)
                if fv5291[:ri].present?
                  fv5290 = Rack::Utils.parse_nested_query(fv5289.query.to_s)
                  fv5290["ri"] ||= fv5291[:ri].to_s
                  fv5289.query = URI.encode_www_form(fv5290)
                end
                fv5275.host!(fv5289.host)
                fv5275.https!
                fv5288 = fv5289.request_uri
                fv5271 = fv5284.merge("Host" => fv5289.host)
                fv5275.get(fv5288, headers: fv5271)
              else
                fv5285.confirm_base!(
                  base_token: fv5287,
                  browser_digest: AuthAdmissionBinding.browser_digest(
                    surface: fv5286,
                    entry_ref: fv5285.entry_ref,
                    nonce: "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn",
                  ),
                )
                fv5283 = fv5275.host
                fv5275.host!(fv5283)
                fv5275.https!
                fv5271 = fv5284.merge("Host" => fv5283)
                fv5275.get(fv5282, params: fv5281, headers: fv5271)
              end
              fv5274, fv5272, fv5273 =
                begin
                  fv5280 = fv5275.response.body
                  fv5279 = false
                  fv5278 = Nokogiri::HTML(fv5280).at_css("form")
                  if fv5278.nil? && fv5279
                    nil
                  else
                    raise RuntimeError, "Auth continuation form is missing" unless fv5278

                    fv5277 = fv5278.at_css("input[name='authenticity_token']")&.[]("value")
                    raise RuntimeError,
                          "Auth continuation is missing its CSRF token" if fv5277.blank?

                    fv5276 = fv5278.css("input[type='hidden']").to_h do |input|
                      [input["name"], input["value"]]
                    end.except("authenticity_token")
                    [fv5278["action"], fv5277, fv5276]
                  end
                end
              fv5275.post(
                fv5274,
                params: fv5273.merge(authenticity_token: fv5272),
                headers: fv5271,
              )
            end
          end
        end
      end

      assert_equal 303, browser.response.status, browser.response.body
      browser.get(new_auth_app_verification_registration_passkey_path(ri: "jp"), headers: auth_headers)

      assert_equal 200, browser.response.status
      page = JSON.parse(Nokogiri::HTML(browser.response.body).at_css("script[data-page='app']").text)
      panel = page.fetch("props").fetch("panel")
      csrf = Nokogiri::HTML(browser.response.body).at_css('meta[name="csrf-token"]')["content"]
      browser.post(
        panel.fetch("options_url"), params: { "cf-turnstile-response" => "synthetic" },
                                    headers: auth_headers.merge("X-CSRF-Token" => csrf), as: :json,
      )

      assert_equal 200, browser.response.status
      options = browser.response.parsed_body
      fake = WebAuthn::FakeClient.new("https://#{auth_host}", encoding: :base64url)
      credential = fake.create(challenge: options.fetch("options").fetch("challenge"), user_verified: true)
      passkey_count = ClientPasskey.count
      browser.post(
        panel.fetch("verification_url"),
        params: { credential: credential, challenge_id: options.fetch("challenge_id") },
        headers: auth_headers.merge("X-CSRF-Token" => csrf), as: :json,
      )

      assert_equal 201, browser.response.status, browser.response.body
      assert_equal passkey_count, ClientPasskey.count
      handoff_uri = URI.parse(browser.response.parsed_body.fetch("redirect_url"))
      handoff_path = handoff_uri.path
      handoff_path = "#{handoff_path}?#{handoff_uri.query}" if handoff_uri.query.present?
      browser.get(handoff_path, headers: auth_headers)
      handoff_form = Nokogiri::HTML(browser.response.body).at_css("form")
      browser.post(
        handoff_form["action"],
        params: { authenticity_token: handoff_form.at_css('input[name="authenticity_token"]')["value"] },
        headers: auth_headers,
      )

      assert_equal 303, browser.response.status
      completion_uri = URI.parse(browser.response.location)
      base.host!(completion_uri.host)
      base.https!
      base.get(completion_uri.request_uri, headers: base_headers)
      completion_form = Nokogiri::HTML(base.response.body).at_css("form")
      completion_params = completion_form.css("input[name]").to_h { |input| [input["name"], input["value"]] }
      base.post(completion_form["action"], params: completion_params, headers: base_headers)

      assert_equal 303, base.response.status
      assert_equal passkey_count + 1, ClientPasskey.count
      destination = URI.parse(base.response.location)

      assert_equal base_host, destination.host
      issuance = ClientSecretIssuance.find_by!(client_id: actor.id, origin: "passkey_registration")
      expected_count = [2, 20 - active_count].min

      assert_equal expected_count, issuance.planned_count
      assert_nil issuance.encrypted_payload
      base.get(destination.request_uri, headers: base_headers)

      assert_equal 200, base.response.status
      page = JSON.parse(Nokogiri::HTML(base.response.body).at_css("script[data-page='app']").text)
      csrf = page.fetch("props").fetch("authenticity_token")
      if active_count == 19
        assert_equal I18n.t("base.app.secrets.distribution_one_present"), page.fetch("props").fetch("notice")
      elsif active_count == 20
        assert_equal I18n.t("base.app.secrets.distribution_omitted"), page.fetch("props").fetch("notice")
        assert_nil issuance.reload.encrypted_payload
        assert_nil issuance.expires_at
        assert_equal 0, ClientSecretCredential.where(issuance_id: issuance.id).count
        assert_equal 0, ClientSecretCapacityQuery.call(client: actor, at: Client.database_now).reserved_count
        assert_equal "omitted", page.fetch("props").fetch("state")
        next
      else
        assert_nil page.fetch("props").fetch("notice")
      end
      base.post(
        base_app_secret_issuance_presentation_path(issuance.public_id, ri: "jp"),
        headers: base_headers, params: { authenticity_token: csrf },
      )

      assert_equal 200, base.response.status
      values = Nokogiri::HTML(base.response.body).css("[data-secret-value] code").map(&:text)

      assert_equal expected_count, values.length
      values.each { |value| assert_nil ClientSecretLookupQuery.call(client: actor, secret: value) }
      csrf = Nokogiri::HTML(base.response.body).at_css('input[name="authenticity_token"]')["value"]
      base.patch(
        base_app_secret_issuance_path(issuance.public_id, ri: "jp"),
        headers: base_headers, params: { authenticity_token: csrf, stored: "1" },
      )

      assert_equal 303, base.response.status
      values.each { |value| assert ClientSecretLookupQuery.call(client: actor, secret: value) }
      assert_equal active_count + expected_count,
                   ClientSecretCapacityQuery.call(client: actor, at: Client.database_now).active_count
      base.get(base_app_secret_issuance_path(issuance.public_id, ri: "jp"), headers: base_headers)

      assert_equal 200, base.response.status
      if active_count == 19
        page = JSON.parse(Nokogiri::HTML(base.response.body).at_css("script[data-page='app']").text)

        assert_equal I18n.t("base.app.secrets.distribution_one_confirmed"), page.fetch("props").fetch("notice")
      end
    end
  end

  test "unavailable manual payload retires candidates and releases capacity through the protected HTTP endpoint" do
    [nil, "invalid encrypted payload"].each do |payload|
      base_host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
      actor = Client.create!(status_id: ClientStatus::ACTIVE)
      token = ClientToken.create!(
        user: actor, established_authentication_method: "secret", root_login_established_at: ClientToken.database_now,
      )
      BaseSelectorBootstrapAuthority.call(surface: :app, principal: actor)
      BaseSelectorAuthority.prepare(surface: :app, principal: actor, session: token)
      token.update!(
        last_step_up_at: ClientToken.database_now, last_step_up_scope: "settings_secret_credential",
        last_step_up_method: "passkey", last_step_up_session_public_id: token.public_id,
        last_step_up_purpose: "step_up", last_step_up_audience: "step_up:app",
        last_step_up_phishing_resistant: true, last_step_up_user_verified: true,
        last_step_up_credential_ref: "test-step-up", last_step_up_full_reauthentication: false,
      )
      context = ActorValuesContext.empty.with(subject: actor, actor_type: :client, tld: :app, surface: :base)
      issuance = ClientSecretManualReservationIssuer.call!(
        actor_context: context, token: token, operation_id: SecureRandom.uuid, expires_after: 1.minute,
      )
      ClientSecretPresentationIssuer.prepare!(actor_context: context, token: token, issuance: issuance)
      issuance.reload.update!(encrypted_payload: payload)
      base = open_session
      base.host!(base_host)
      base.https!
      begin
        fv5265 = base
        fv5268 = actor
        fv5270 = token
        fv5263 = base_host
        fv5267 = OidcClientRegistry.find!("base-app-ww")
        fv5269 = ClientRpSession.database_now
        fv5264 = ClientRpSession.create!(
          client_token: fv5270,
          oidc_client_id: fv5267.client_id,
          oidc_scope: "openid profile",
          oidc_jti: SecureRandom.uuid,
          oidc_nonce: SecureRandom.hex(16),
          oidc_auth_time: fv5270.root_login_established_at || fv5269,
          refresh_token_expires_at: fv5269 + 30.minutes,
        )
        fv5266 = AuthenticationTokenService.encode(
          fv5268,
          host: fv5263,
          resource_type: "client",
          session_public_id: fv5270.public_id,
          base_session_public_id: fv5270.public_id,
          oidc_sid: fv5264.public_id,
          oidc_jti: fv5264.oidc_jti,
          expires_at: fv5269 + 10.minutes,
          scopes: %w(openid profile),
          issuer: OidcIssuer.for_client(fv5267),
          audiences: [fv5267.aud],
          jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(fv5267),
          subject: OidcSubject.for(fv5268, resource_type: "client"),
          client_id: fv5267.client_id,
        )
        fv5265.cookies[OidcRpBrowserCredentialContract::ACCESS_COOKIE] =
          fv5266
        fv5265.cookies.merge(
          "#{OidcRpBrowserCredentialContract::REFRESH_COOKIE}=#{Rack::Utils.escape(fv5264.issue_refresh_token!)}",
          URI.parse("https://#{fv5263}/"),
        )
      end
      headers = {
        "Host" => base_host, "Origin" => "https://#{base_host}", "Sec-Fetch-Site" => "same-origin",
      }
      base.get(base_app_secret_issuance_path(issuance.public_id, ri: "jp"), headers: headers)

      assert_equal 200, base.response.status
      page = JSON.parse(Nokogiri::HTML(base.response.body).at_css("script[data-page='app']").text)
      csrf = page.fetch("props").fetch("authenticity_token")
      assert_no_difference "ClientSecretCredential.count" do
        base.post(
          base_app_secret_issuance_presentation_path(issuance.public_id, ri: "jp"),
          headers: headers, params: { authenticity_token: csrf },
        )
      end

      assert_equal 410, base.response.status
      assert_nil issuance.reload.encrypted_payload
      assert_not_nil issuance.canceled_at
      assert_equal ["payload_unavailable"], ClientSecretAuditOutbox.where(
        operation_ref: issuance.origin_operation_id,
        event_name: %w(secret.issuance_canceled secret.discarded),
      ).distinct.pluck(:reason)
      assert_equal 0, ClientSecretCapacityQuery.call(client: actor, at: Client.database_now).reserved_count
      candidate = ClientSecretCredential.find_by!(issuance_id: issuance.id)

      assert_nil candidate.confirmed_at
      assert_not_nil candidate.discard_at
      base.patch(
        base_app_secret_issuance_path(issuance.public_id, ri: "jp"),
        headers: headers, params: { authenticity_token: csrf, stored: "1" },
      )

      assert_equal 403, base.response.status
      assert_nil candidate.reload.confirmed_at
      assert_nil issuance.reload.confirmed_at
    end
  end

  test "manual HTTP delivery and storage confirmation lead to one canonical Base Secret login" do # rubocop:disable Minitest/MultipleAssertions -- Verifies each observable boundary in one browser journey.
    base_host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    auth_host = ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
    issuer = JitSecurityJwtRegistry.surface("BASE_APP")
    actor = Client.create!(status_id: ClientStatus::ACTIVE, birthdate: "2000-01-01")
    identifier = "secret-login-#{SecureRandom.hex(4)}@example.com"
    actor.client_emails.create!(
      address: identifier, user_email_status_id: ClientEmailStatus::VERIFIED,
    ).finalize_binding!
    fake = WebAuthn::FakeClient.new("https://#{auth_host}", encoding: :base64url)
    registration = fake.create(
      challenge: Base64.urlsafe_encode64(SecureRandom.random_bytes(32), padding: false), user_verified: true,
    )
    relying_party = WebAuthn::RelyingParty.new(
      id: auth_host, allowed_origins: ["https://#{auth_host}"], encoding: :base64url,
    )
    registered = WebAuthn::Credential.from_create(registration, relying_party: relying_party)
    passkey = actor.client_passkeys.create!(
      webauthn_id: registered.id, public_key: registered.public_key, sign_count: 0,
    )
    token = ClientToken.create!(
      user: actor, established_authentication_method: "passkey",
      root_login_established_at: ClientToken.database_now - 1.hour,
    )
    BaseSelectorBootstrapAuthority.call(surface: :app, principal: actor)
    BaseSelectorAuthority.prepare(surface: :app, principal: actor, session: token)
    # This fixture establishes scoped admission; WebAuthn verification has its own journey tests.
    token.update!(
      last_step_up_at: ClientToken.database_now, last_step_up_scope: "settings_secret_credential",
      last_step_up_method: "passkey", last_step_up_session_public_id: token.public_id,
      last_step_up_purpose: "step_up", last_step_up_audience: "step_up:app",
      last_step_up_phishing_resistant: true, last_step_up_user_verified: true,
      last_step_up_credential_ref: "test-step-up", last_step_up_full_reauthentication: false,
    )

    assert_predicate StepUpResolver.call(
      token: token.reload, requirement: StepUpRequirement.new(
        step_up_required: true, scope: "settings_secret_credential", allowed_methods: %i(passkey totp email_otp),
        phishing_resistant_required: false, user_verification_required: false,
        full_reauthentication_required: false, ttl: StepUpRequirement::DEFAULT_TTL,
        purpose: "step_up", audience: "step_up:app", session_binding: token.public_id,
        token_binding: token.public_id, require_session_binding: true,
        actor_ref: actor.public_id, resource_ref: nil, tenant_ref: nil,
      ),
    ), :satisfied?
    base_client = OidcClientRegistry.find!("base-app-ww")
    base_rp_session = ClientRpSession.create!(
      client_token: token, oidc_client_id: base_client.client_id, oidc_scope: "openid profile",
      oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16), oidc_auth_time: token.root_login_established_at,
      refresh_token_expires_at: 10.minutes.from_now,
    )
    base_rp_access_token = AuthenticationTokenService.encode(
      actor, host: base_host, resource_type: "client", session_public_id: token.public_id,
             base_session_public_id: token.public_id, oidc_sid: base_rp_session.public_id,
             oidc_jti: base_rp_session.oidc_jti, expires_at: 10.minutes.from_now,
             scopes: %w(openid profile), issuer: OidcIssuer.for_client(base_client),
             audiences: [base_client.aud], jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(base_client),
             subject: OidcSubject.for(actor, resource_type: "client"), client_id: base_client.client_id,
    )
    base_rp_refresh_token = base_rp_session.issue_refresh_token!
    host!(base_host)
    https!
    cookies[OidcRpBrowserCredentialContract::ACCESS_COOKIE] = base_rp_access_token
    cookies[OidcRpBrowserCredentialContract::REFRESH_COOKIE] = base_rp_refresh_token
    rp_payload = OidcRpBrowserCredentialContract.decode_access_token(
      token: base_rp_access_token, host: base_host, resource_type: "client", client_id: "base-app-ww",
    )

    assert_predicate rp_payload, :present?
    assert_equal base_rp_session.public_id, AuthorizationTokenClaims.session_id(rp_payload)
    assert_predicate base_rp_session, :active?
    assert_predicate base_rp_session.parent_device_session, :usable?
    assert_equal token.id, base_rp_session.parent_token.id
    headers = { "Origin" => "https://#{base_host}", "Sec-Fetch-Site" => "same-origin" }
    get new_base_app_secret_path(ri: "jp"), headers: headers

    assert_response :success
    page = JSON.parse(response.parsed_body.at_css("script[data-page='app']").text)
    csrf = page.fetch("props").fetch("authenticity_token")
    operation_id = page.fetch("props").fetch("operation_id")
    post base_app_secrets_path(ri: "jp"), params: {
      authenticity_token: csrf, operation_id: operation_id,
    }, headers: headers

    assert_response :see_other
    issuance = ClientSecretIssuance.find_by!(client_id: actor.id)

    assert_equal 1, issuance.planned_count
    assert_nil issuance.confirmed_at
    candidate = ClientSecretCredential.find_by!(issuance_id: issuance.id)
    post base_app_secret_issuance_presentation_path(issuance.public_id, ri: "jp"),
         params: { authenticity_token: csrf }, headers: headers

    assert_response :success
    assert_includes response.headers.fetch("Cache-Control"), "no-store"
    assert_equal "no-referrer", response.headers["Referrer-Policy"]
    assert_nil response.headers["X-Inertia"]
    raw = response.parsed_body.at_css("[data-secret-value] code").text

    assert_match(/\A[1-9A-HJ-NP-Za-km-z]{32}\z/, raw)
    assert_nil ClientSecretLookupQuery.call(client: actor, secret: raw)
    csrf = response.parsed_body.at_css('input[name="authenticity_token"]')["value"]
    patch base_app_secret_issuance_path(issuance.public_id, ri: "jp"),
          params: { authenticity_token: csrf, stored: "1" }, headers: headers

    assert_response :see_other
    assert_equal candidate.id, ClientSecretLookupQuery.call(client: actor, secret: raw).id

    assert_no_difference ["ClientSecretIssuance.count", "ClientSecretCredential.count",
                          "ClientSecretAuditOutbox.count",] do
      post base_app_secrets_path(ri: "jp"), params: { authenticity_token: csrf, operation_id: operation_id },
                                            headers: headers
    end
    assert_redirected_to base_app_secret_issuance_path(issuance.public_id, ri: "jp")

    base = open_session
    auth_uri =
      begin
        fv5247 = base
        fv5246 = base_host
        fv5247.host!(fv5246)
        fv5247.https!
        fv5247.get("/sign", params: { ri: "jp" })
        fv5262 = Nokogiri::HTML(fv5247.response.body).at_css('input[name="authenticity_token"]')["value"]
        fv5247.post(
          "/sign", params: { ri: "jp", authenticity_token: fv5262 }, headers: {
            "Origin" => "https://#{fv5246}", "Sec-Fetch-Site" => "same-origin",
          },
        )

        fv5255 =
          begin
            fv5261 = fv5247.response.location
            fv5257 = fv5246
            fv5260 = URI.parse(fv5261)
            fv5259 = Rack::Utils.parse_query(fv5260.query).fetch("rt")
            fv5258 = JitSecurityJwtRegistry.surface("BASE_APP")
            fv5256, = JWT.decode(
              fv5259,
              JitSecurityJwtRegistry.public_key_for(
                fv5258.id,
                fv5258.current_kid,
              ),
              true,
              algorithms: ["ES384"],
              verify_iss: true,
              iss: "https://#{fv5257}",
              verify_aud: true,
              aud: Rails.configuration.x.boot_config.fetch(:jump).audience,
            )
            URI.parse(fv5256.fetch("url"))
          end

        assert_equal fv5246, fv5255.host
        assert_equal "/oauth/authorize", fv5255.path
        fv5247.host!(fv5255.host)
        fv5247.https!
        fv5247.get(fv5255.request_uri)
        fv5211 = Nokogiri::HTML(fv5247.response.body).at_css("form#base-authorization-ceremony-start-form")

        assert fv5211
        fv5247.post(
          fv5211["action"],
          params: fv5211.css("input[name]").to_h { |fv5254|
            [fv5254["name"], fv5254["value"]]
          },
          headers: { "Origin" => "https://#{fv5246}",
                     "Sec-Fetch-Site" => "same-origin", },
        )
        begin
          fv5248 = fv5247
          fv5250 = JitSessionCookieConfig.cookie_key(force_secure: JitSessionCookieConfig.force_secure?)
          fv5249 = fv5248.response.cookies[fv5250]
          if fv5249.nil?
            fv5253 = fv5248.response.headers["Set-Cookie"] || fv5248.response.headers["set-cookie"]
            fv5252 =
              if fv5253.is_a?(String) && fv5253.start_with?("[")
                JSON.parse(fv5253)
              else
                Array(fv5253)
              end
            fv5251 =
              fv5252.flat_map { |entry| entry.to_s.split("\n") }.find do |entry|
                entry.split(";", 2).first.to_s.start_with?("#{fv5250}=")
              end
            if fv5251

              _, fv5249 = fv5251.split(";", 2).first.to_s.split("=", 2)
              fv5249 = Rack::Utils.unescape(fv5249.to_s)
            end
          end

          unless fv5249.nil?
            fv5248.cookies.delete(fv5250)
            # Rack::Test's []= uses its default host. The current request may target a
            # different surface, so install the cookie against the browser's active host.
            fv5248.cookies.merge(
              "#{fv5250}=#{Rack::Utils.escape(fv5249)}",
              URI.parse("https://#{fv5248.host}/"),
            )
          end
        end

        begin
          fv5245 = fv5247.response.location
          fv5241 = fv5246
          fv5244 = URI.parse(fv5245)
          fv5243 = Rack::Utils.parse_query(fv5244.query).fetch("rt")
          fv5242 = JitSecurityJwtRegistry.surface("BASE_APP")
          fv5240, = JWT.decode(
            fv5243,
            JitSecurityJwtRegistry.public_key_for(
              fv5242.id,
              fv5242.current_kid,
            ),
            true,
            algorithms: ["ES384"],
            verify_iss: true,
            iss: "https://#{fv5241}",
            verify_aud: true,
            aud: Rails.configuration.x.boot_config.fetch(:jump).audience,
          )
          URI.parse(fv5240.fetch("url"))
        end
      end
    entry_ref = Rack::Utils.parse_query(auth_uri.query).fetch("entry_ref")
    authorization = BaseAuthAdmissionCoordinator.find_admission_binding!(surface: "app", reference: entry_ref)
      .authorization_transaction
    browser = open_session
    browser.host!(auth_host)
    browser.https!
    auth_headers = {
      "Host" => auth_host, "Origin" => "https://#{auth_host}", "Sec-Fetch-Site" => "same-origin",
    }
    begin
      fv5239 = browser
      fv5238 = auth_uri.path
      fv5237 = entry_ref
      fv5236 = :entry_ref
      fv5235 = { ri: "jp" }
      fv5234 = auth_headers
      fv5233 = true
      fv5232 = base
      begin
        fv5180 = fv5239
        fv5187 = fv5238
        fv5230 = fv5237
        fv5231 = fv5236
        fv5196 = fv5235
        fv5189 = fv5234
        fv5218 = fv5233
        fv5217 = fv5232
        fv5192 = nil
        fv5186 = fv5196.merge(fv5231 => fv5230)
        fv5180.get(fv5187, params: fv5186, headers: fv5189)
        fv5224 =
          begin
            fv5229 = fv5180.response.body
            fv5228 = true
            fv5227 = Nokogiri::HTML(fv5229).at_css("form")
            if fv5227.nil? && fv5228
              nil
            else
              raise RuntimeError, "Auth continuation form is missing" unless fv5227

              fv5226 = fv5227.at_css("input[name='authenticity_token']")&.[]("value")
              raise RuntimeError,
                    "Auth continuation is missing its CSRF token" if fv5226.blank?

              fv5225 = fv5227.css("input[type='hidden']").to_h do |input|
                [input["name"], input["value"]]
              end.except("authenticity_token")
              [fv5227["action"], fv5226, fv5225]
            end
          end
        if fv5224

          fv5223, fv5221, fv5222 = fv5224

          fv5180.session[BaseAdmissionBrowserBinding::BROWSER_NONCE_SESSION_KEY] ||=
            "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn"
          fv5180.post(
            fv5223, params: fv5222.merge(authenticity_token: fv5221),
                    headers: fv5189,
          )
          fv5220 = fv5180.response.location
          if fv5220.present?

            fv5216 = URI.parse(fv5220)
            fv5215 = fv5216.host
            fv5191 =
              begin
                fv5219 = fv5215
                {
                  ENV.fetch("PUBLIC_BASE_SERVICE_URL") => "app",
                  ENV.fetch("PUBLIC_BASE_CORPORATE_URL") => "com",
                  ENV.fetch("PUBLIC_BASE_STAFF_URL") => "org",
                }.fetch(fv5219)
              end
            fv5190 = BaseAuthAdmissionCoordinator.find_admission_binding_by_confirmation!(
              surface: fv5191, reference: fv5216.path.split("/").fetch(-2),
            )

            if fv5218
              fv5198 = fv5217 || fv5180
              fv5198.host!(fv5215)
              fv5198.https!
              fv5198.session[BaseAdmissionBrowserBinding::BROWSER_NONCE_SESSION_KEY] ||=
                "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn"
              fv5214 = fv5216.request_uri
              fv5205 = fv5189.merge(
                "Host" => fv5215,
                "Origin" => "https://#{fv5215}",
                "Sec-Fetch-Site" => "same-origin",
              )
              fv5198.get(fv5214, headers: fv5205)
              fv5208, fv5206, fv5207 =
                begin
                  fv5213 = fv5198.response.body
                  fv5212 = false
                  fv5211 = Nokogiri::HTML(fv5213).at_css("form")
                  if fv5211.nil? && fv5212
                    nil
                  else
                    raise RuntimeError, "Auth continuation form is missing" unless fv5211

                    fv5210 = fv5211.at_css("input[name='authenticity_token']")&.[]("value")
                    raise RuntimeError,
                          "Auth continuation is missing its CSRF token" if fv5210.blank?

                    fv5209 = fv5211.css("input[type='hidden']").to_h do |input|
                      [input["name"], input["value"]]
                    end.except("authenticity_token")
                    [fv5211["action"], fv5210, fv5209]
                  end
                end
              fv5198.post(
                fv5208,
                params: fv5207.merge(authenticity_token: fv5206),
                headers: fv5205,
              )
              begin
                fv5199 = fv5198
                fv5201 = "session"
                fv5200 = fv5199.response.cookies[fv5201]
                if fv5200.nil?
                  fv5204 = fv5199.response.headers["Set-Cookie"] || fv5199.response.headers["set-cookie"]
                  fv5203 =
                    if fv5204.is_a?(String) && fv5204.start_with?("[")
                      JSON.parse(fv5204)
                    else
                      Array(fv5204)
                    end
                  fv5202 =
                    fv5203.flat_map { |entry| entry.to_s.split("\n") }.find do |entry|
                      entry.split(";", 2).first.to_s.start_with?("#{fv5201}=")
                    end
                  if fv5202

                    _, fv5200 = fv5202.split(";", 2).first.to_s.split("=", 2)
                    fv5200 = Rack::Utils.unescape(fv5200.to_s)
                  end
                end

                unless fv5200.nil?
                  fv5199.cookies.delete(fv5201)
                  # Rack::Test's []= uses its default host. The current request may target a
                  # different surface, so install the cookie against the browser's active host.
                  fv5199.cookies.merge(
                    "#{fv5201}=#{Rack::Utils.escape(fv5200)}",
                    URI.parse("https://#{fv5199.host}/"),
                  )
                end
              end
              fv5197 = fv5198.response.location
              raise RuntimeError, "Base confirmation did not return to Auth" if fv5197.blank?

              fv5194 = URI.parse(fv5197)
              if fv5196[:ri].present?
                fv5195 = Rack::Utils.parse_nested_query(fv5194.query.to_s)
                fv5195["ri"] ||= fv5196[:ri].to_s
                fv5194.query = URI.encode_www_form(fv5195)
              end
              fv5180.host!(fv5194.host)
              fv5180.https!
              fv5193 = fv5194.request_uri
              fv5176 = fv5189.merge("Host" => fv5194.host)
              fv5180.get(fv5193, headers: fv5176)
            else
              fv5190.confirm_base!(
                base_token: fv5192,
                browser_digest: AuthAdmissionBinding.browser_digest(
                  surface: fv5191,
                  entry_ref: fv5190.entry_ref,
                  nonce: "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn",
                ),
              )
              fv5188 = fv5180.host
              fv5180.host!(fv5188)
              fv5180.https!
              fv5176 = fv5189.merge("Host" => fv5188)
              fv5180.get(fv5187, params: fv5186, headers: fv5176)
            end
            fv5179, fv5177, fv5178 =
              begin
                fv5185 = fv5180.response.body
                fv5184 = false
                fv5183 = Nokogiri::HTML(fv5185).at_css("form")
                if fv5183.nil? && fv5184
                  nil
                else
                  raise RuntimeError, "Auth continuation form is missing" unless fv5183

                  fv5182 = fv5183.at_css("input[name='authenticity_token']")&.[]("value")
                  raise RuntimeError,
                        "Auth continuation is missing its CSRF token" if fv5182.blank?

                  fv5181 = fv5183.css("input[type='hidden']").to_h do |input|
                    [input["name"], input["value"]]
                  end.except("authenticity_token")
                  [fv5183["action"], fv5182, fv5181]
                end
              end
            fv5180.post(
              fv5179,
              params: fv5178.merge(authenticity_token: fv5177),
              headers: fv5176,
            )
          end
        end
      end
    end

    assert_equal 303, browser.response.status
    browser.get(new_auth_app_sign_in_secret_path(ri: "jp"))

    assert_equal 200, browser.response.status
    page = JSON.parse(Nokogiri::HTML(browser.response.body).at_css("script[data-page='app']").text)
    csrf = page.fetch("props").fetch("authenticity_token")
    assert_no_difference("ClientToken.count") do
      browser.post(
        auth_app_sign_in_secret_path(ri: "jp"), params: {
          :identifier => identifier,
          :secret => raw,
          :authenticity_token => csrf,
          "cf-turnstile-response" => "synthetic",
        }, headers: auth_headers,
      )
    end
    assert_equal 303, browser.response.status
    assert_nil ClientSecretLookupQuery.call(client: actor, secret: raw)
    browser.follow_redirect!

    assert_equal 302, browser.response.status
    browser.follow_redirect! if browser.response.redirect?

    assert_equal 200, browser.response.status
    csrf = Nokogiri::HTML(browser.response.body).at_css('input[name="authenticity_token"]')["value"]
    browser.post(
      auth_app_sign_oidc_handoff_path(ri: "jp"), params: { authenticity_token: csrf }, headers: auth_headers,
    )

    assert_equal 303, browser.response.status
    result_uri = URI.parse(browser.response.location)
    base.host!(result_uri.host)
    base.https!
    base.get(result_uri.request_uri, headers: { "Host" => result_uri.host })

    assert_equal 200, base.response.status
    result_form = Nokogiri::HTML(base.response.body).at_css("form")
    result_csrf = result_form.at_css('input[name="authenticity_token"]')["value"]
    result = result_form.at_css('input[name="result_ref"]')["value"]
    transaction_ref = result_form.at_css('input[name="transaction_ref"]')["value"]
    base_headers = {
      "Host" => result_uri.host, "Origin" => "https://#{result_uri.host}", "Sec-Fetch-Site" => "same-origin",
    }
    assert_difference("ClientToken.count", 1) do
      base.post(
        result_form["action"],
        params: { result_ref: result, transaction_ref: transaction_ref, authenticity_token: result_csrf },
        headers: base_headers,
      )
    end
    assert_equal 303, base.response.status
    callback_uri =
      begin
        fv5175 = base.response.location
        fv5171 = base_host
        fv5174 = URI.parse(fv5175)
        fv5173 = Rack::Utils.parse_query(fv5174.query).fetch("rt")
        fv5172 = JitSecurityJwtRegistry.surface("BASE_APP")
        fv5170, = JWT.decode(
          fv5173, JitSecurityJwtRegistry.public_key_for(
            fv5172.id,
            fv5172.current_kid,
          ), true,
          algorithms: ["ES384"], verify_iss: true, iss: "https://#{fv5171}",
          verify_aud: true, aud: Rails.configuration.x.boot_config.fetch(:jump).audience,
        )
        URI.parse(fv5170.fetch("url"))
      end
    base.host!(callback_uri.host)
    base.https!
    flow = authorization.reload.secret_sign_in_flow
    root = flow.reload.token
    id_token = OidcIdTokenIssuer.call(
      resource: actor,
      client: OidcClientRegistry.find!("base-app-ww"),
      nonce: authorization.reload.nonce,
      auth_time: authorization.authenticated_at,
    )
    rp_client = OidcClientRegistry.find!("base-app-ww")
    rp_session = ClientRpSession.create!(
      client_token: root,
      oidc_client_id: rp_client.client_id,
      oidc_scope: "openid profile",
      oidc_jti: SecureRandom.uuid,
      oidc_nonce: SecureRandom.hex(16),
      oidc_auth_time: authorization.authenticated_at,
      refresh_token_expires_at: 10.minutes.from_now,
    )
    rp_access_token = AuthenticationTokenService.encode(
      actor,
      host: base_host,
      resource_type: "client",
      session_public_id: root.public_id,
      base_session_public_id: root.public_id,
      oidc_sid: rp_session.public_id,
      oidc_jti: rp_session.oidc_jti,
      expires_at: 10.minutes.from_now,
      scopes: %w(openid profile),
      issuer: OidcIssuer.for_client(rp_client),
      audiences: [rp_client.aud],
      jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(rp_client),
      subject: OidcSubject.for(actor, resource_type: "client"),
      client_id: rp_client.client_id,
    )
    token_result = OidcRpTokenClient::Result.new(
      success: true,
      token_response: {
        access_token: rp_access_token,
        refresh_token: rp_session.issue_refresh_token!,
        id_token: id_token,
        expires_in: 600,
        refresh_token_expires_in: 3600,
      },
      error: nil,
    )
    userinfo_result = OidcRpUserInfoClient::Result.new(
      success: true,
      claims: { "sub" => OidcSubject.for(actor, resource_type: "client") },
      error: nil,
      dependency_failure: false,
    )
    OidcRpTokenClient.stub(:call, token_result) do
      OidcRpUserInfoClient.stub(:call, userinfo_result) do
        base.get(callback_uri.request_uri, headers: { "Host" => callback_uri.host })
      end
    end
    set_cookie = base.response.headers.fetch("Set-Cookie")
    set_cookie = JSON.parse(set_cookie) if set_cookie.is_a?(String) && set_cookie.start_with?("[")

    assert_includes Array(set_cookie).join("\n"), "#{OidcRpBrowserCredentialContract::ACCESS_COOKIE}="
    base.cookies.delete(OidcRpBrowserCredentialContract::ACCESS_COOKIE)
    base.cookies.delete(OidcRpBrowserCredentialContract::REFRESH_COOKIE)
    base.cookies[OidcRpBrowserCredentialContract::ACCESS_COOKIE] = rp_access_token
    base.cookies[OidcRpBrowserCredentialContract::REFRESH_COOKIE] = token_result.token_response.fetch(:refresh_token)
    callback_access_payload = OidcRpBrowserCredentialContract.decode_access_token(
      token: base.cookies[OidcRpBrowserCredentialContract::ACCESS_COOKIE], host: base_host,
      resource_type: "client", client_id: "base-app-ww",
    )

    assert_equal rp_session.public_id, AuthorizationTokenClaims.session_id(callback_access_payload)

    assert_equal "secret", root.established_authentication_method
    receipt = ClientSecretSignInReceipt.find_by!(operation_id: candidate.reload.claim_operation_id)

    assert_equal root.public_id, receipt.root_token_ref
    assert_equal candidate.public_id, receipt.credential_ref
    assert_equal actor.public_id, receipt.client_ref
    assert candidate.reload.consumed_at
    assert_nil ClientSecretLookupQuery.call(client: actor, secret: raw)
    assert_not_nil base.cookies[AuthenticationBase::ACCESS_COOKIE_KEY]
    assert_nil browser.cookies[AuthenticationBase::ACCESS_COOKIE_KEY]
    assert_no_difference("ClientToken.count") do
      base.post(
        result_form["action"],
        params: { result_ref: result, transaction_ref: transaction_ref, authenticity_token: result_csrf },
        headers: base_headers,
      )
    end
    assert_nil root.reload.last_step_up_at
    base.get(new_base_app_secret_path(ri: "jp"))

    assert_equal 302, base.response.status
    assert_nil root.reload.last_step_up_at
    base.follow_redirect!
    verification_page = Nokogiri::HTML(base.response.body)
    verification_props = JSON.parse(verification_page.at_css("script[data-page='app']").text).fetch("props")
    intent = verification_props.fetch("form")
    csrf = verification_page.at_css('meta[name="csrf-token"]')["content"]
    original_name = candidate.name
    assert_no_difference -> { ClientSecretIssuance.count + ClientSecretAuditOutbox.count } do
      base.post(
        base_app_secrets_path(ri: "jp"), params: { authenticity_token: csrf },
                                         headers: { "Origin" => "https://#{base_host}" },
      )

      assert_equal 401, base.response.status
      base.patch(
        base_app_secret_path(candidate.public_id, ri: "jp"),
        params: { authenticity_token: csrf, name: "Unauthorized rename" },
        headers: { "Origin" => "https://#{base_host}" },
      )

      assert_equal 401, base.response.status
      base.delete(
        base_app_secret_path(candidate.public_id, ri: "jp"),
        params: { authenticity_token: csrf }, headers: { "Origin" => "https://#{base_host}" },
      )

      assert_equal 401, base.response.status
    end
    assert_equal original_name, candidate.reload.name
    assert_nil candidate.revoked_at
    assert_nil root.reload.last_step_up_at
    base.post(
      intent.fetch("action"), params: {
        scope: intent.fetch("scope"), pt: intent.fetch("pt"), authenticity_token: csrf,
      }, headers: { "Origin" => "https://#{base_host}", "Sec-Fetch-Site" => "same-origin" },
    )

    assert_equal 303, base.response.status
    begin
      fv5164 = base
      fv5166 = "session"
      fv5165 = fv5164.response.cookies[fv5166]
      if fv5165.nil?
        fv5169 = fv5164.response.headers["Set-Cookie"] || fv5164.response.headers["set-cookie"]
        fv5168 =
          if fv5169.is_a?(String) && fv5169.start_with?("[")
            JSON.parse(fv5169)
          else
            Array(fv5169)
          end
        fv5167 =
          fv5168.flat_map { |entry| entry.to_s.split("\n") }.find do |entry|
            entry.split(";", 2).first.to_s.start_with?("#{fv5166}=")
          end
        if fv5167

          _, fv5165 = fv5167.split(";", 2).first.to_s.split("=", 2)
          fv5165 = Rack::Utils.unescape(fv5165.to_s)
        end
      end

      unless fv5165.nil?
        fv5164.cookies.delete(fv5166)
        # Rack::Test's []= uses its default host. The current request may target a
        # different surface, so install the cookie against the browser's active host.
        fv5164.cookies.merge(
          "#{fv5166}=#{Rack::Utils.escape(fv5165)}",
          URI.parse("https://#{fv5164.host}/"),
        )
      end
    end
    rt = Rack::Utils.parse_query(URI.parse(base.response.location).query).fetch("rt")
    step_up_jump, = JWT.decode(
      rt, JitSecurityJwtRegistry.public_key_for(issuer.id, issuer.current_kid), true,
      algorithms: ["ES384"], verify_iss: true, iss: "https://#{base_host}",
      verify_aud: true, aud: Rails.configuration.x.boot_config.fetch(:jump).audience,
    )
    step_up_target = URI.parse(step_up_jump.fetch("url"))
    admission_ref = Rack::Utils.parse_query(step_up_target.query).fetch("entry_ref")
    step_up_browser = open_session
    step_up_browser.host!(auth_host)
    step_up_browser.https!
    step_up_headers = {
      "Host" => auth_host, "Origin" => "https://#{auth_host}", "Sec-Fetch-Site" => "same-origin",
    }
    begin
      fv5163 = step_up_browser
      fv5162 = step_up_target.path
      fv5161 = admission_ref
      fv5160 = :entry_ref
      fv5159 = { ri: "jp" }
      fv5158 = step_up_headers
      fv5157 = true
      fv5156 = base
      begin
        fv5104 = fv5163
        fv5111 = fv5162
        fv5154 = fv5161
        fv5155 = fv5160
        fv5120 = fv5159
        fv5113 = fv5158
        fv5142 = fv5157
        fv5141 = fv5156
        fv5116 = nil
        fv5110 = fv5120.merge(fv5155 => fv5154)
        fv5104.get(fv5111, params: fv5110, headers: fv5113)
        fv5148 =
          begin
            fv5153 = fv5104.response.body
            fv5152 = true
            fv5151 = Nokogiri::HTML(fv5153).at_css("form")
            if fv5151.nil? && fv5152
              nil
            else
              raise RuntimeError, "Auth continuation form is missing" unless fv5151

              fv5150 = fv5151.at_css("input[name='authenticity_token']")&.[]("value")
              raise RuntimeError,
                    "Auth continuation is missing its CSRF token" if fv5150.blank?

              fv5149 = fv5151.css("input[type='hidden']").to_h do |input|
                [input["name"], input["value"]]
              end.except("authenticity_token")
              [fv5151["action"], fv5150, fv5149]
            end
          end
        if fv5148

          fv5147, fv5145, fv5146 = fv5148

          fv5104.session[BaseAdmissionBrowserBinding::BROWSER_NONCE_SESSION_KEY] ||=
            "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn"
          fv5104.post(
            fv5147, params: fv5146.merge(authenticity_token: fv5145),
                    headers: fv5113,
          )
          fv5144 = fv5104.response.location
          if fv5144.present?

            fv5140 = URI.parse(fv5144)
            fv5139 = fv5140.host
            fv5115 =
              begin
                fv5143 = fv5139
                {
                  ENV.fetch("PUBLIC_BASE_SERVICE_URL") => "app",
                  ENV.fetch("PUBLIC_BASE_CORPORATE_URL") => "com",
                  ENV.fetch("PUBLIC_BASE_STAFF_URL") => "org",
                }.fetch(fv5143)
              end
            fv5114 = BaseAuthAdmissionCoordinator.find_admission_binding_by_confirmation!(
              surface: fv5115, reference: fv5140.path.split("/").fetch(-2),
            )

            if fv5142
              fv5122 = fv5141 || fv5104
              fv5122.host!(fv5139)
              fv5122.https!
              fv5122.session[BaseAdmissionBrowserBinding::BROWSER_NONCE_SESSION_KEY] ||=
                "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn"
              fv5138 = fv5140.request_uri
              fv5129 = fv5113.merge(
                "Host" => fv5139,
                "Origin" => "https://#{fv5139}",
                "Sec-Fetch-Site" => "same-origin",
              )
              fv5122.get(fv5138, headers: fv5129)
              fv5132, fv5130, fv5131 =
                begin
                  fv5137 = fv5122.response.body
                  fv5136 = false
                  fv5135 = Nokogiri::HTML(fv5137).at_css("form")
                  if fv5135.nil? && fv5136
                    nil
                  else
                    raise RuntimeError, "Auth continuation form is missing" unless fv5135

                    fv5134 = fv5135.at_css("input[name='authenticity_token']")&.[]("value")
                    raise RuntimeError,
                          "Auth continuation is missing its CSRF token" if fv5134.blank?

                    fv5133 = fv5135.css("input[type='hidden']").to_h do |input|
                      [input["name"], input["value"]]
                    end.except("authenticity_token")
                    [fv5135["action"], fv5134, fv5133]
                  end
                end
              fv5122.post(
                fv5132,
                params: fv5131.merge(authenticity_token: fv5130),
                headers: fv5129,
              )
              begin
                fv5123 = fv5122
                fv5125 = "session"
                fv5124 = fv5123.response.cookies[fv5125]
                if fv5124.nil?
                  fv5128 = fv5123.response.headers["Set-Cookie"] || fv5123.response.headers["set-cookie"]
                  fv5127 =
                    if fv5128.is_a?(String) && fv5128.start_with?("[")
                      JSON.parse(fv5128)
                    else
                      Array(fv5128)
                    end
                  fv5126 =
                    fv5127.flat_map { |entry| entry.to_s.split("\n") }.find do |entry|
                      entry.split(";", 2).first.to_s.start_with?("#{fv5125}=")
                    end
                  if fv5126

                    _, fv5124 = fv5126.split(";", 2).first.to_s.split("=", 2)
                    fv5124 = Rack::Utils.unescape(fv5124.to_s)
                  end
                end

                unless fv5124.nil?
                  fv5123.cookies.delete(fv5125)
                  # Rack::Test's []= uses its default host. The current request may target a
                  # different surface, so install the cookie against the browser's active host.
                  fv5123.cookies.merge(
                    "#{fv5125}=#{Rack::Utils.escape(fv5124)}",
                    URI.parse("https://#{fv5123.host}/"),
                  )
                end
              end
              fv5121 = fv5122.response.location
              raise RuntimeError, "Base confirmation did not return to Auth" if fv5121.blank?

              fv5118 = URI.parse(fv5121)
              if fv5120[:ri].present?
                fv5119 = Rack::Utils.parse_nested_query(fv5118.query.to_s)
                fv5119["ri"] ||= fv5120[:ri].to_s
                fv5118.query = URI.encode_www_form(fv5119)
              end
              fv5104.host!(fv5118.host)
              fv5104.https!
              fv5117 = fv5118.request_uri
              fv5100 = fv5113.merge("Host" => fv5118.host)
              fv5104.get(fv5117, headers: fv5100)
            else
              fv5114.confirm_base!(
                base_token: fv5116,
                browser_digest: AuthAdmissionBinding.browser_digest(
                  surface: fv5115,
                  entry_ref: fv5114.entry_ref,
                  nonce: "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn",
                ),
              )
              fv5112 = fv5104.host
              fv5104.host!(fv5112)
              fv5104.https!
              fv5100 = fv5113.merge("Host" => fv5112)
              fv5104.get(fv5111, params: fv5110, headers: fv5100)
            end
            fv5103, fv5101, fv5102 =
              begin
                fv5109 = fv5104.response.body
                fv5108 = false
                fv5107 = Nokogiri::HTML(fv5109).at_css("form")
                if fv5107.nil? && fv5108
                  nil
                else
                  raise RuntimeError, "Auth continuation form is missing" unless fv5107

                  fv5106 = fv5107.at_css("input[name='authenticity_token']")&.[]("value")
                  raise RuntimeError,
                        "Auth continuation is missing its CSRF token" if fv5106.blank?

                  fv5105 = fv5107.css("input[type='hidden']").to_h do |input|
                    [input["name"], input["value"]]
                  end.except("authenticity_token")
                  [fv5107["action"], fv5106, fv5105]
                end
              end
            fv5104.post(
              fv5103,
              params: fv5102.merge(authenticity_token: fv5101),
              headers: fv5100,
            )
          end
        end
      end
    end
    step_up_browser.get(new_auth_app_verification_passkey_path(ri: "jp"))
    step_up_page = Nokogiri::HTML(step_up_browser.response.body)
    panel = JSON.parse(step_up_page.at_css("script[data-page='app']").text).fetch("props").fetch("panel")
    csrf = step_up_page.at_css('meta[name="csrf-token"]')["content"]
    step_up_browser.post(
      panel.fetch("options_url"), params: { "cf-turnstile-response" => "synthetic" },
                                  headers: { "X-CSRF-Token" => csrf, "Origin" => "https://#{auth_host}" }, as: :json,
    )

    assert_equal 200, step_up_browser.response.status
    options = step_up_browser.response.parsed_body
    assertion = fake.get(
      challenge: options.fetch("options").fetch("challenge"), user_present: true, user_verified: true, sign_count: 2,
    )
    step_up_browser.post(
      panel.fetch("verification_url"), params: {
        credential: assertion, challenge_id: options.fetch("challenge_id"),
      }, headers: { "X-CSRF-Token" => csrf, "Origin" => "https://#{auth_host}" }, as: :json,
    )

    assert_equal 200, step_up_browser.response.status
    assert_nil root.reload.last_step_up_at
    step_up_browser.get(step_up_browser.response.parsed_body.fetch("redirect_url"))
    form = Nokogiri::HTML(step_up_browser.response.body).at_css("form")
    step_up_browser.post(
      form["action"], params: {
        authenticity_token: form.at_css('input[name="authenticity_token"]')["value"],
      }, headers: step_up_headers,
    )

    assert_equal 303, step_up_browser.response.status
    completion_uri = URI.parse(step_up_browser.response.location)
    base.host!(completion_uri.host)
    base.https!
    base_headers = {
      "Host" => completion_uri.host,
      "Origin" => "https://#{completion_uri.host}",
      "Sec-Fetch-Site" => "same-origin",
    }
    base.get(completion_uri.request_uri, headers: base_headers)

    assert_equal 200, base.response.status
    form = Nokogiri::HTML(base.response.body).at_css("form")
    completion_params = form.css("input[name]").to_h { |input| [input["name"], input["value"]] }
    step_up_transaction = ClientStepUpCeremonyTransaction.find_by!(
      transaction_id: completion_params.fetch("transaction_ref"),
    )
    base.post(
      form["action"], params: completion_params,
                      headers: base_headers,
    )

    assert_equal 303, base.response.status,
                 "#{base.response.body} params=#{completion_params.inspect} tx=#{step_up_transaction.reload.status} " \
                 "token_method=#{root.reload.last_step_up_method.inspect} passkey=#{passkey.reload.sign_count}"
    assert_equal "passkey", root.reload.last_step_up_method
    assert_equal "settings_secret_credential", root.last_step_up_scope
    assert_equal "secret", root.established_authentication_method
    assert_equal 2, passkey.reload.sign_count
    begin
      fv5094 = base
      fv5096 = OidcRpBrowserCredentialContract::ACCESS_COOKIE
      fv5095 = fv5094.response.cookies[fv5096]
      if fv5095.nil?
        fv5099 = fv5094.response.headers["Set-Cookie"] || fv5094.response.headers["set-cookie"]
        fv5098 =
          if fv5099.is_a?(String) && fv5099.start_with?("[")
            JSON.parse(fv5099)
          else
            Array(fv5099)
          end
        fv5097 =
          fv5098.flat_map { |entry| entry.to_s.split("\n") }.find do |entry|
            entry.split(";", 2).first.to_s.start_with?("#{fv5096}=")
          end
        if fv5097

          _, fv5095 = fv5097.split(";", 2).first.to_s.split("=", 2)
          fv5095 = Rack::Utils.unescape(fv5095.to_s)
        end
      end

      unless fv5095.nil?
        fv5094.cookies.delete(fv5096)
        # Rack::Test's []= uses its default host. The current request may target a
        # different surface, so install the cookie against the browser's active host.
        fv5094.cookies.merge(
          "#{fv5096}=#{Rack::Utils.escape(fv5095)}",
          URI.parse("https://#{fv5094.host}/"),
        )
      end
    end
    begin
      fv5088 = base
      fv5090 = OidcRpBrowserCredentialContract::REFRESH_COOKIE
      fv5089 = fv5088.response.cookies[fv5090]
      if fv5089.nil?
        fv5093 = fv5088.response.headers["Set-Cookie"] || fv5088.response.headers["set-cookie"]
        fv5092 =
          if fv5093.is_a?(String) && fv5093.start_with?("[")
            JSON.parse(fv5093)
          else
            Array(fv5093)
          end
        fv5091 =
          fv5092.flat_map { |entry| entry.to_s.split("\n") }.find do |entry|
            entry.split(";", 2).first.to_s.start_with?("#{fv5090}=")
          end
        if fv5091

          _, fv5089 = fv5091.split(";", 2).first.to_s.split("=", 2)
          fv5089 = Rack::Utils.unescape(fv5089.to_s)
        end
      end

      unless fv5089.nil?
        fv5088.cookies.delete(fv5090)
        # Rack::Test's []= uses its default host. The current request may target a
        # different surface, so install the cookie against the browser's active host.
        fv5088.cookies.merge(
          "#{fv5090}=#{Rack::Utils.escape(fv5089)}",
          URI.parse("https://#{fv5088.host}/"),
        )
      end
    end
    base.get(new_base_app_secret_path(ri: "jp"))

    assert_equal 200, base.response.status
    page = JSON.parse(Nokogiri::HTML(base.response.body).at_css("script[data-page='app']").text)
    csrf = page.fetch("props").fetch("authenticity_token")
    operation_id = page.fetch("props").fetch("operation_id")
    assert_difference("ClientSecretIssuance.count", 1) do
      base.post(
        base_app_secrets_path(ri: "jp"), params: { authenticity_token: csrf, operation_id: operation_id },
                                         headers: { "Origin" => "https://#{base_host}" },
      )
    end
    assert_equal 303, base.response.status
    assert_equal 1, ClientSecretCapacityQuery.call(client: actor, at: Client.database_now).reserved_count
    additional_issuance = ClientSecretIssuance.find_by!(client_id: actor.id, browser_session_ref: root.public_id)
    base.post(
      base_app_secret_issuance_presentation_path(additional_issuance.public_id, ri: "jp"),
      params: { authenticity_token: csrf }, headers: { "Origin" => "https://#{base_host}" },
    )

    assert_equal 200, base.response.status
    presentation = Nokogiri::HTML(base.response.body)
    additional_raw = presentation.at_css("[data-secret-value] code").text
    csrf = presentation.at_css('input[name="authenticity_token"]')["value"]

    assert_nil ClientSecretLookupQuery.call(client: actor, secret: additional_raw)
    base.patch(
      base_app_secret_issuance_path(additional_issuance.public_id, ri: "jp"),
      params: { authenticity_token: csrf, stored: "1" }, headers: { "Origin" => "https://#{base_host}" },
    )

    assert_equal 303, base.response.status
    additional = ClientSecretLookupQuery.call(client: actor, secret: additional_raw)

    assert additional
    base.patch(
      base_app_secret_path(additional.public_id, ri: "jp"),
      params: { authenticity_token: csrf, name: "Saved after independent Step-Up" },
      headers: { "Origin" => "https://#{base_host}" },
    )

    assert_equal 303, base.response.status
    assert_equal "Saved after independent Step-Up", additional.reload.name
    base.delete(
      base_app_secret_path(additional.public_id, ri: "jp"),
      params: { authenticity_token: csrf }, headers: { "Origin" => "https://#{base_host}" },
    )

    assert_equal 303, base.response.status
    assert additional.reload.revoked_at
    assert_nil ClientSecretLookupQuery.call(client: actor, secret: additional_raw)
    assert_equal 0, ClientSecretCapacityQuery.call(client: actor, at: Client.database_now).active_count
    assert_equal ClientTokenStatus::ACTIVE, root.reload.user_token_status_id
    retry_base = open_session
    retry_browser = open_session
    retry_auth_uri =
      begin
        fv5071 = retry_base
        fv5070 = base_host
        fv5071.host!(fv5070)
        fv5071.https!
        fv5071.get("/sign", params: { ri: "jp" })
        fv5087 = Nokogiri::HTML(fv5071.response.body).at_css('input[name="authenticity_token"]')["value"]
        fv5071.post(
          "/sign", params: { ri: "jp", authenticity_token: fv5087 }, headers: {
            "Origin" => "https://#{fv5070}", "Sec-Fetch-Site" => "same-origin",
          },
        )

        fv5080 =
          begin
            fv5086 = fv5071.response.location
            fv5082 = fv5070
            fv5085 = URI.parse(fv5086)
            fv5084 = Rack::Utils.parse_query(fv5085.query).fetch("rt")
            fv5083 = JitSecurityJwtRegistry.surface("BASE_APP")
            fv5081, = JWT.decode(
              fv5084,
              JitSecurityJwtRegistry.public_key_for(
                fv5083.id,
                fv5083.current_kid,
              ),
              true,
              algorithms: ["ES384"],
              verify_iss: true,
              iss: "https://#{fv5082}",
              verify_aud: true,
              aud: Rails.configuration.x.boot_config.fetch(:jump).audience,
            )
            URI.parse(fv5081.fetch("url"))
          end

        assert_equal fv5070, fv5080.host
        assert_equal "/oauth/authorize", fv5080.path
        fv5071.host!(fv5080.host)
        fv5071.https!
        fv5071.get(fv5080.request_uri)
        fv5079 = Nokogiri::HTML(fv5071.response.body).at_css("form#base-authorization-ceremony-start-form")

        assert fv5079
        fv5071.post(
          fv5079["action"],
          params: fv5079.css("input[name]").to_h { |fv5078|
            [fv5078["name"], fv5078["value"]]
          },
          headers: { "Origin" => "https://#{fv5070}",
                     "Sec-Fetch-Site" => "same-origin", },
        )
        begin
          fv5072 = fv5071
          fv5074 = JitSessionCookieConfig.cookie_key(force_secure: JitSessionCookieConfig.force_secure?)
          fv5073 = fv5072.response.cookies[fv5074]
          if fv5073.nil?
            fv5077 = fv5072.response.headers["Set-Cookie"] || fv5072.response.headers["set-cookie"]
            fv5076 =
              if fv5077.is_a?(String) && fv5077.start_with?("[")
                JSON.parse(fv5077)
              else
                Array(fv5077)
              end
            fv5075 =
              fv5076.flat_map { |entry| entry.to_s.split("\n") }.find do |entry|
                entry.split(";", 2).first.to_s.start_with?("#{fv5074}=")
              end
            if fv5075

              _, fv5073 = fv5075.split(";", 2).first.to_s.split("=", 2)
              fv5073 = Rack::Utils.unescape(fv5073.to_s)
            end
          end

          unless fv5073.nil?
            fv5072.cookies.delete(fv5074)
            # Rack::Test's []= uses its default host. The current request may target a
            # different surface, so install the cookie against the browser's active host.
            fv5072.cookies.merge(
              "#{fv5074}=#{Rack::Utils.escape(fv5073)}",
              URI.parse("https://#{fv5072.host}/"),
            )
          end
        end

        begin
          fv5069 = fv5071.response.location
          fv5065 = fv5070
          fv5068 = URI.parse(fv5069)
          fv5067 = Rack::Utils.parse_query(fv5068.query).fetch("rt")
          fv5066 = JitSecurityJwtRegistry.surface("BASE_APP")
          fv5064, = JWT.decode(
            fv5067,
            JitSecurityJwtRegistry.public_key_for(
              fv5066.id,
              fv5066.current_kid,
            ),
            true,
            algorithms: ["ES384"],
            verify_iss: true,
            iss: "https://#{fv5065}",
            verify_aud: true,
            aud: Rails.configuration.x.boot_config.fetch(:jump).audience,
          )
          URI.parse(fv5064.fetch("url"))
        end
      end
    retry_entry_ref = Rack::Utils.parse_query(retry_auth_uri.query).fetch("entry_ref")
    retry_browser.host!(auth_host)
    retry_browser.https!
    retry_auth_headers = {
      "Host" => auth_host, "Origin" => "https://#{auth_host}", "Sec-Fetch-Site" => "same-origin",
    }
    begin
      fv5063 = retry_browser
      fv5062 = retry_auth_uri.path
      fv5061 = retry_entry_ref
      fv5060 = :entry_ref
      fv5059 = { ri: "us" }
      fv5058 = retry_auth_headers
      fv5057 = true
      fv5056 = retry_base
      begin
        fv5004 = fv5063
        fv5011 = fv5062
        fv5054 = fv5061
        fv5055 = fv5060
        fv5020 = fv5059
        fv5013 = fv5058
        fv5042 = fv5057
        fv5041 = fv5056
        fv5016 = nil
        fv5010 = fv5020.merge(fv5055 => fv5054)
        fv5004.get(fv5011, params: fv5010, headers: fv5013)
        fv5048 =
          begin
            fv5053 = fv5004.response.body
            fv5052 = true
            fv5051 = Nokogiri::HTML(fv5053).at_css("form")
            if fv5051.nil? && fv5052
              nil
            else
              raise RuntimeError, "Auth continuation form is missing" unless fv5051

              fv5050 = fv5051.at_css("input[name='authenticity_token']")&.[]("value")
              raise RuntimeError,
                    "Auth continuation is missing its CSRF token" if fv5050.blank?

              fv5049 = fv5051.css("input[type='hidden']").to_h do |input|
                [input["name"], input["value"]]
              end.except("authenticity_token")
              [fv5051["action"], fv5050, fv5049]
            end
          end
        if fv5048

          fv5047, fv5045, fv5046 = fv5048

          fv5004.session[BaseAdmissionBrowserBinding::BROWSER_NONCE_SESSION_KEY] ||=
            "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn"
          fv5004.post(
            fv5047, params: fv5046.merge(authenticity_token: fv5045),
                    headers: fv5013,
          )
          fv5044 = fv5004.response.location
          if fv5044.present?

            fv5040 = URI.parse(fv5044)
            fv5039 = fv5040.host
            fv5015 =
              begin
                fv5043 = fv5039
                {
                  ENV.fetch("PUBLIC_BASE_SERVICE_URL") => "app",
                  ENV.fetch("PUBLIC_BASE_CORPORATE_URL") => "com",
                  ENV.fetch("PUBLIC_BASE_STAFF_URL") => "org",
                }.fetch(fv5043)
              end
            fv5014 = BaseAuthAdmissionCoordinator.find_admission_binding_by_confirmation!(
              surface: fv5015, reference: fv5040.path.split("/").fetch(-2),
            )

            if fv5042
              fv5022 = fv5041 || fv5004
              fv5022.host!(fv5039)
              fv5022.https!
              fv5022.session[BaseAdmissionBrowserBinding::BROWSER_NONCE_SESSION_KEY] ||=
                "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn"
              fv5038 = fv5040.request_uri
              fv5029 = fv5013.merge(
                "Host" => fv5039,
                "Origin" => "https://#{fv5039}",
                "Sec-Fetch-Site" => "same-origin",
              )
              fv5022.get(fv5038, headers: fv5029)
              fv5032, fv5030, fv5031 =
                begin
                  fv5037 = fv5022.response.body
                  fv5036 = false
                  fv5035 = Nokogiri::HTML(fv5037).at_css("form")
                  if fv5035.nil? && fv5036
                    nil
                  else
                    raise RuntimeError, "Auth continuation form is missing" unless fv5035

                    fv5034 = fv5035.at_css("input[name='authenticity_token']")&.[]("value")
                    raise RuntimeError,
                          "Auth continuation is missing its CSRF token" if fv5034.blank?

                    fv5033 = fv5035.css("input[type='hidden']").to_h do |input|
                      [input["name"], input["value"]]
                    end.except("authenticity_token")
                    [fv5035["action"], fv5034, fv5033]
                  end
                end
              fv5022.post(
                fv5032,
                params: fv5031.merge(authenticity_token: fv5030),
                headers: fv5029,
              )
              begin
                fv5023 = fv5022
                fv5025 = "session"
                fv5024 = fv5023.response.cookies[fv5025]
                if fv5024.nil?
                  fv5028 = fv5023.response.headers["Set-Cookie"] || fv5023.response.headers["set-cookie"]
                  fv5027 =
                    if fv5028.is_a?(String) && fv5028.start_with?("[")
                      JSON.parse(fv5028)
                    else
                      Array(fv5028)
                    end
                  fv5026 =
                    fv5027.flat_map { |entry| entry.to_s.split("\n") }.find do |entry|
                      entry.split(";", 2).first.to_s.start_with?("#{fv5025}=")
                    end
                  if fv5026

                    _, fv5024 = fv5026.split(";", 2).first.to_s.split("=", 2)
                    fv5024 = Rack::Utils.unescape(fv5024.to_s)
                  end
                end

                unless fv5024.nil?
                  fv5023.cookies.delete(fv5025)
                  # Rack::Test's []= uses its default host. The current request may target a
                  # different surface, so install the cookie against the browser's active host.
                  fv5023.cookies.merge(
                    "#{fv5025}=#{Rack::Utils.escape(fv5024)}",
                    URI.parse("https://#{fv5023.host}/"),
                  )
                end
              end
              fv5021 = fv5022.response.location
              raise RuntimeError, "Base confirmation did not return to Auth" if fv5021.blank?

              fv5018 = URI.parse(fv5021)
              if fv5020[:ri].present?
                fv5019 = Rack::Utils.parse_nested_query(fv5018.query.to_s)
                fv5019["ri"] ||= fv5020[:ri].to_s
                fv5018.query = URI.encode_www_form(fv5019)
              end
              fv5004.host!(fv5018.host)
              fv5004.https!
              fv5017 = fv5018.request_uri
              fv5000 = fv5013.merge("Host" => fv5018.host)
              fv5004.get(fv5017, headers: fv5000)
            else
              fv5014.confirm_base!(
                base_token: fv5016,
                browser_digest: AuthAdmissionBinding.browser_digest(
                  surface: fv5015,
                  entry_ref: fv5014.entry_ref,
                  nonce: "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn",
                ),
              )
              fv5012 = fv5004.host
              fv5004.host!(fv5012)
              fv5004.https!
              fv5000 = fv5013.merge("Host" => fv5012)
              fv5004.get(fv5011, params: fv5010, headers: fv5000)
            end
            fv5003, fv5001, fv5002 =
              begin
                fv5009 = fv5004.response.body
                fv5008 = false
                fv5007 = Nokogiri::HTML(fv5009).at_css("form")
                if fv5007.nil? && fv5008
                  nil
                else
                  raise RuntimeError, "Auth continuation form is missing" unless fv5007

                  fv5006 = fv5007.at_css("input[name='authenticity_token']")&.[]("value")
                  raise RuntimeError,
                        "Auth continuation is missing its CSRF token" if fv5006.blank?

                  fv5005 = fv5007.css("input[type='hidden']").to_h do |input|
                    [input["name"], input["value"]]
                  end.except("authenticity_token")
                  [fv5007["action"], fv5006, fv5005]
                end
              end
            fv5004.post(
              fv5003,
              params: fv5002.merge(authenticity_token: fv5001),
              headers: fv5000,
            )
          end
        end
      end
    end

    assert_equal 303, retry_browser.response.status
    retry_browser.get(
      new_auth_app_sign_in_secret_path(ri: "us"),
      headers: retry_auth_headers,
    )

    assert_equal 200, retry_browser.response.status
    page = JSON.parse(Nokogiri::HTML(retry_browser.response.body).at_css("script[data-page='app']").text)
    csrf = page.fetch("props").fetch("authenticity_token")
    assert_no_difference -> { ClientToken.count + ClientSecretSignInReceipt.count } do
      retry_browser.post(
        auth_app_sign_in_secret_path(ri: "us"), params: {
          :secret => raw, :authenticity_token => csrf, "cf-turnstile-response" => "synthetic",
        }, headers: retry_auth_headers,
      )
    end
    assert_equal 422, retry_browser.response.status
    assert_equal 1, ClientSecretSignInReceipt.where(credential_ref: candidate.public_id).count
  end

  private
end
