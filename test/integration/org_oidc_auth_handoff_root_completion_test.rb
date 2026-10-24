# frozen_string_literal: true

require "test_helper"
require "minitest/mock"
require "webauthn/fake_client"
require "faraday"

# Keep browser/proof values out of assertion output and the whole journey in one browser context.
# rubocop:disable Minitest/MultipleAssertions
class OrgOidcAuthHandoffRootCompletionTest < ActionDispatch::IntegrationTest
  %i(complete missing_primary missing_mfa expired_mfa).each do |outcome|
    test "org real OIDC Entra and Passkey #{outcome} preserves Base root authority" do
      previous_protection = ActionController::Base.allow_forgery_protection
      previous_omniauth = OmniAuth.config.test_mode
      previous_turnstile = [TurnstileVerifierStub.enabled, TurnstileVerifierStub.response]
      previous_challenge = [TurnstileVerifierStub.challenge_enabled, TurnstileVerifierStub.challenge_response]
      ActionController::Base.allow_forgery_protection = true
      OmniAuth.config.test_mode = false
      TurnstileVerifierStub.enabled = true
      TurnstileVerifierStub.response = { "success" => true }
      TurnstileVerifierStub.challenge_enabled = true
      TurnstileVerifierStub.challenge_response = { "success" => true }
      base_host = ENV.fetch("PUBLIC_BASE_STAFF_URL")
      auth_host = ENV.fetch("PUBLIC_AUTH_STAFF_URL")
      origin = "https://#{auth_host}"
      base_headers = { "Origin" => "https://#{base_host}", "Sec-Fetch-Site" => nil }
      auth_headers = { "Origin" => origin, "Sec-Fetch-Site" => nil }
      actor = Operator.create!(
        status_id: OperatorStatus::ACTIVE,
        security_mode_id: SecurityModeConfigurable::NORMAL, mfa_status_id: OperatorMfaStatus::UNCONFIGURED,
      )
      tenant = ExternalAuthentication::ProviderRegistry.tenant_id("entra")
      audience = ExternalAuthentication::ProviderRegistry.audience("entra")
      entra_issuer = ExternalAuthentication::ProviderRegistry.issuer_for("entra")
      object_id = SecureRandom.uuid
      OrganizationEntraConnectionState.ensure_defaults!
      OperatorEntraIdentityState.ensure_defaults!
      identity = OperatorEntraIdentity.create!(
        operator_id: actor.id, entra_tenant_id: tenant, entra_object_id: object_id,
        status_id: OperatorEntraIdentityState::ACTIVE,
      )
      authenticator = WebAuthn::FakeClient.new(origin, encoding: :base64url)
      registration = authenticator.create(
        challenge: Base64.urlsafe_encode64(SecureRandom.random_bytes(32), padding: false), user_verified: true,
      )
      relying_party = WebAuthn::RelyingParty.new(id: auth_host, allowed_origins: [origin], encoding: :base64url)
      credential = WebAuthn::Credential.from_create(registration, relying_party: relying_party)
      passkey = actor.operator_passkeys.create!(
        webauthn_id: credential.id, public_key: credential.public_key, sign_count: 0,
        status_id: OperatorPasskeyStatus::ACTIVE, description: "OIDC normal sign-in journey",
      )
      browser = open_session
      browser.host!(base_host)
      browser.https!
      browser.get("/sign", params: { ri: "jp" })

      assert_equal 200, browser.response.status
      cookie_name = JitSessionCookieConfig.cookie_key(force_secure: JitSessionCookieConfig.force_secure?)
      csrf = browser.response.parsed_body.at_css('input[name="authenticity_token"]')["value"]
      browser.post("/sign", params: { ri: "jp", authenticity_token: csrf }, headers: base_headers)

      assert_equal 303, browser.response.status
      issuer = JitSecurityJwtRegistry.surface("BASE_ORG")
      base_session_cookie = browser.cookies[cookie_name]
      visa_session_cookie = nil
      entry_reference = nil
      visa_host = visa_host_for_test_base_host(base_host)
      jump_host = URI.parse(Rails.configuration.x.boot_config.fetch(:jump).origin.to_s).host
      current_host = base_host
      12.times do
        break unless browser.response.redirect?

        target = URI.parse(browser.response.location.to_s)
        target = URI.parse("https://#{current_host}#{target}") if target.host.blank?
        if target.host == jump_host
          rt = Rack::Utils.parse_query(target.query).fetch("rt")
          namespace = current_host == base_host ? "BASE_ORG" : "VISA_ORG"
          issuer = JitSecurityJwtRegistry.surface(namespace)
          payload, = JWT.decode(
            rt, JitSecurityJwtRegistry.public_key_for(issuer.id, issuer.current_kid), true,
            algorithms: ["ES384"], verify_iss: true, iss: "https://#{current_host}",
            verify_aud: true, aud: Rails.configuration.x.boot_config.fetch(:jump).audience,
          )
          target = URI.parse(payload.fetch("url"))
        end

        query = Rack::Utils.parse_query(target.query.to_s)
        entry_reference ||= query["entry_ref"] if query["entry_ref"].present?
        assert_equal "https", target.scheme
        assert_includes [base_host, visa_host, auth_host], target.host
        browser.host!(target.host)
        browser.get(
          target.request_uri,
          headers: {
            "Sec-Fetch-Mode" => "navigate",
            "Sec-Fetch-Dest" => "document",
            "Sec-Fetch-Site" => current_host == target.host ? "same-origin" : "cross-site",
          },
        )
        visa_session_cookie = browser.cookies[cookie_name] if target.host == visa_host
        current_host = target.host
      end

      assert_equal auth_host, browser.host
      assert_equal 200, browser.response.status
      binding = BaseAuthAdmissionCoordinator.find_admission_binding!(surface: "org", reference: entry_reference)
      parent = authorization_transaction_for_test(binding)
      original_parent_id = parent.id
      original_binding_id = binding.id
      assert_withheld { binding.reload.redeemed? }
      ceremony = OperatorAuthCeremonySession.find(binding.admitted_auth_ceremony_session_id)

      assert_withheld("Admission must retain its original parent") {
        ceremony.authorization_transaction_ref == parent.transaction_id
      }
      browser.get("/sign/in", params: { ri: "jp" })

      assert_equal 200, browser.response.status
      csrf = browser.response.parsed_body.at_css('meta[name="csrf-token"]')["content"]
      if outcome == :missing_primary
        before_parent = parent.reload.attributes
        before_identity = identity.reload.attributes
        before_passkey = passkey.reload.attributes
        browser.get(
          "/sign/oidc/handoff", params: { ri: "jp" },
          headers: auth_headers.merge(
            "Sec-Fetch-Mode" => "navigate", "Sec-Fetch-Dest" => "document", "Sec-Fetch-Site" => "same-origin",
          ),
        )

        assert_equal 400, browser.response.status
        browser.post("/sign/oidc/handoff", params: { ri: "jp", authenticity_token: csrf }, headers: auth_headers)

        assert_equal 404, browser.response.status
        assert_withheld("Missing Entra must not authenticate or consume the parent") {
          before_parent == parent.reload.attributes
        }
        assert_withheld("Missing Entra must preserve the provisioned identity") {
          before_identity == identity.reload.attributes
        }
        assert_withheld("Missing Entra must preserve the credential") { before_passkey == passkey.reload.attributes }
        assert_equal 0, OperatorToken.where(staff_id: actor.id).count
        next
      end

      browser.get(new_auth_org_social_entra_session_path(ri: "jp"))

      assert_equal 200, browser.response.status
      csrf = browser.response.parsed_body.at_css('meta[name="csrf-token"]')["content"]
      # Rack::Test cannot reliably install Rails' encoded multi-value Set-Cookie response.
      # The middleware must receive the same actual session that emitted this CSRF token.
      cookie_name = JitSessionCookieConfig.cookie_key(force_secure: JitSessionCookieConfig.force_secure?)
      cookie_value = browser.response.cookies[cookie_name]
      if cookie_value.nil?
        raw = browser.response.headers["Set-Cookie"] || browser.response.headers["set-cookie"]
        lines = (raw.is_a?(String) && raw.start_with?("[")) ? JSON.parse(raw) : Array(raw)
        line =
          lines.flat_map { |entry| entry.to_s.split("\n") }.find do |entry|
            entry.split(";", 2).first.to_s.start_with?("#{cookie_name}=")
          end
        cookie_value = Rack::Utils.unescape(line.split(";", 2).first.split("=", 2).last) if line
      end
      if cookie_value
        browser.cookies.delete(cookie_name)
        _received_cookie = browser.cookies.merge(
          "#{cookie_name}=#{Rack::Utils.escape(cookie_value)}", URI.parse("https://#{auth_host}/"),
        )
      end
      if outcome == :complete
        [
          [nil, origin], ["invalid-csrf-token", origin],
          [csrf, "https://foreign.example.test"], [csrf, "null"],
        ].each do |invalid_csrf, request_origin|
          before_parent = parent.reload.attributes
          browser.post(
            "/social/entra", params: { ri: "jp", authenticity_token: invalid_csrf },
                             headers: auth_headers.merge("Origin" => request_origin),
          )

          assert_equal 302, browser.response.status
          refusal = URI.parse(browser.response.location)

          assert_withheld { refusal.path == "/social/entra/failure" }
          assert_withheld { Rack::Utils.parse_query(refusal.query).fetch("message") == "csrf_detected" }
          assert_withheld("Rejected initiation must not change its parent") {
            before_parent == parent.reload.attributes
          }
          assert_equal 0, OperatorToken.where(staff_id: actor.id).count
        end
      end
      browser.post("/social/entra", params: { ri: "jp", authenticity_token: csrf }, headers: auth_headers)

      assert_equal 302, browser.response.status
      authorize_uri = URI.parse(browser.response.location)

      failure_reason = Rack::Utils.parse_query(authorize_uri.query).fetch("message", nil)

      assert_equal "https", authorize_uri.scheme, "Entra initiation failure classification: #{failure_reason}"
      assert_equal "login.microsoftonline.com", authorize_uri.host
      assert_withheld(
        "Entra request must reach the configured tenant authorize endpoint, not a local failure redirect",
      ) {
        authorize_uri.path == "/#{tenant}/oauth2/v2.0/authorize"
      }
      authorize_query = Rack::Utils.parse_query(authorize_uri.query)
      private_key = OpenSSL::PKey::RSA.generate(2048)
      jwk = JWT::JWK.new(private_key, { "kid" => "org-oidc-handoff" })
      now = Time.current.to_i
      id_token = JWT.encode(
        { "iss" => entra_issuer,
          "aud" => audience,
          "tid" => tenant,
          "oid" => object_id,
          "sub" => "oidc-normal-operator",
          "acct" => 0,
          "ver" => "2.0",
          "nonce" => authorize_query.fetch("nonce"),
          "iat" => now,
          "exp" => now + 3600, },
        private_key, "RS256", { "kid" => "org-oidc-handoff" },
      )
      # Replace only the external token and key transports, not signature/claim verification or identity lookup.
      token_response = Faraday::Response.new(
        status: 200, body: { "token_type" => "Bearer",
                             "access_token" => "synthetic-entra-access",
                             "id_token" => id_token,
                             "expires_in" => 3600, },
      )
      captured = nil
      transport = Minitest::Mock.new
      transport.expect(:post, token_response) do |uri, params, _headers|
        captured = { uri: uri, params: params }
        true
      end
      key_source = Minitest::Mock.new
      key_source.expect(:loader, ->(_options) { { "keys" => [jwk.export] } })
      Rack::OAuth2.stub(:http_client, transport) do
        ExternalSignIn::EntraJwksCache.stub(:new, key_source) do
          browser.get(
            "/social/entra/callback", params: {
              state: authorize_query.fetch("state"), code: "synthetic-authorization-code",
            },
          )
        end
      end
      transport.verify
      key_source.verify

      assert_equal "login.microsoftonline.com", URI.parse(captured.fetch(:uri)).host
      assert_withheld("Real token exchange must carry PKCE") { captured.fetch(:params).fetch(:code_verifier).present? }
      assert_equal 303, browser.response.status
      passkey_binding = Rack::Utils.parse_nested_query(
        URI.parse(browser.response.location).query.to_s,
      ).fetch("fb")

      assert_equal 0, OperatorToken.where(staff_id: actor.id).count
      assert_withheld { identity.reload.last_authenticated_at.present? }
      browser.get(URI.parse(browser.response.location).request_uri)

      assert_equal 200, browser.response.status
      csrf = browser.response.parsed_body.at_css('meta[name="csrf-token"]')["content"]
      if %i(missing_mfa expired_mfa).include?(outcome)
        before_parent = parent.reload.attributes
        before_passkey = passkey.reload.attributes
        if outcome == :expired_mfa
          pending = browser.session.fetch(OrgNormalSignInTransaction::SESSION_KEY)
          travel_to(Time.zone.at(pending.fetch("expires_at")))
          browser.post(
            auth_org_sign_in_passkey_options_path(fb: passkey_binding, ri: "jp"),
            params: { "cf-turnstile-response" => "test" },
            headers: auth_headers.merge("X-CSRF-Token" => csrf), as: :json,
          )

          assert_equal 422, browser.response.status
        end
        browser.get(
          "/sign/oidc/handoff", params: { ri: "jp" },
          headers: auth_headers.merge(
            "Sec-Fetch-Mode" => "navigate", "Sec-Fetch-Dest" => "document", "Sec-Fetch-Site" => "same-origin",
          ),
        )

        assert_equal 400, browser.response.status
        browser.post("/sign/oidc/handoff", params: { ri: "jp", authenticity_token: csrf }, headers: auth_headers)

        assert_equal 404, browser.response.status
        assert_withheld("Incomplete MFA must not authenticate or consume the parent") {
          before_parent == parent.reload.attributes
        }
        assert_withheld("Incomplete MFA must preserve the credential") { before_passkey == passkey.reload.attributes }
        assert_equal 0, OperatorToken.where(staff_id: actor.id).count
        next
      end
      browser.post(
        auth_org_sign_in_passkey_options_path(fb: passkey_binding, ri: "jp"),
        params: { "cf-turnstile-response" => "test" },
        headers: auth_headers.merge("X-CSRF-Token" => csrf), as: :json,
      )

      assert_equal 200, browser.response.status
      options = browser.response.parsed_body
      assertion = authenticator.get(
        challenge: options.fetch("options").fetch("challenge"),
        user_present: true, user_verified: true, sign_count: 1,
      )
      browser.post(
        auth_org_sign_in_passkey_verification_path(fb: passkey_binding, ri: "jp"), params: {
          challenge_id: options.fetch("challenge_id"), credential: assertion,
        }, headers: auth_headers.merge("X-CSRF-Token" => csrf), as: :json,
      )

      assert_equal 200, browser.response.status
      assert_equal 0, OperatorToken.where(staff_id: actor.id).count
      browser.get(browser.response.parsed_body.fetch("redirect_url"))

      assert_equal 302, browser.response.status
      handoff = URI.parse(browser.response.location)

      assert_equal "/sign/oidc/handoff", handoff.path
      ceremony.reload

      assert_withheld { ceremony.authentication_evidence_recorded? }
      flow_locator = browser.session.fetch(SignInCycleLocator::SESSION_KEYS.fetch(:org))
      flow_ref = flow_locator.fetch("public_id")
      flow = OperatorSignInFlow.find_by!(public_id: flow_ref)

      assert_equal actor.id, flow.principal_id
      assert_withheld { flow.authentication_event_at.present? }
      assert_not flow.sign_in_completed?, "Auth must hand off before Base completes the root flow"
      assert_nil parent.reload.base_finalized_at
      browser.get(
        handoff.request_uri,
        headers: auth_headers.merge(
          "Sec-Fetch-Mode" => "navigate", "Sec-Fetch-Dest" => "document", "Sec-Fetch-Site" => "same-origin",
        ),
      )

      assert_equal 303, browser.response.status
      assert_equal 0, OperatorToken.where(staff_id: actor.id).count
      result = URI.parse(jump_rt_url_from_location_for_test(browser.response.location))

      assert_equal visa_host, result.host
      assert_equal "/oidc/result", result.path
      browser.host!(result.host)
      browser.get(
        result.request_uri,
        headers: {
          "Sec-Fetch-Mode" => "navigate", "Sec-Fetch-Dest" => "document", "Sec-Fetch-Site" => "cross-site",
          "Origin" => "https://#{visa_host}",
          "Cookie" => "#{cookie_name}=#{Rack::Utils.escape(visa_session_cookie)}",
          "HTTP_COOKIE" => "#{cookie_name}=#{Rack::Utils.escape(visa_session_cookie)}",
        },
      )

      assert_equal 303, browser.response.status
      completion = URI.parse(jump_rt_url_from_location_for_test(browser.response.location))

      assert_equal "https", completion.scheme
      assert_equal base_host, completion.host
      assert_equal "/oidc/callback", completion.path
      assert_withheld("Handoff must retain the Entra-selected Operator") { parent.reload.actor_ref == actor.public_id }
      assert_withheld { parent.reload.base_finalized_at.present? }

      # WU-27/D-104: the Visa result is terminal after the first browser navigation. Replaying the
      # same result reference cannot issue another root or re-run the finalization.
      browser.host!(visa_host)
      browser.get(
        result.request_uri,
        headers: {
          "Sec-Fetch-Mode" => "navigate", "Sec-Fetch-Dest" => "document", "Sec-Fetch-Site" => "same-origin",
          "Origin" => "https://#{visa_host}",
          "Cookie" => "#{cookie_name}=#{Rack::Utils.escape(visa_session_cookie)}",
          "HTTP_COOKIE" => "#{cookie_name}=#{Rack::Utils.escape(visa_session_cookie)}",
        },
      )
      assert_equal 400, browser.response.status
      assert_equal 1, OperatorToken.where(staff_id: actor.id).count
      assert_withheld { parent.reload.base_finalized_at.present? }

      browser.host!(base_host)
      # Rack::Test has one active cookie value while this harness traverses the Auth and Base hosts.
      # Restore the Base session before the RP callback; a shared/overwritten cookie would be a
      # different browser.
      assert_withheld("Base must retain its browser session across the Auth hop") { base_session_cookie.present? }
      browser.cookies.delete(cookie_name)
      browser.cookies.merge(
        "#{cookie_name}=#{Rack::Utils.escape(base_session_cookie)}", URI.parse("https://#{base_host}/"),
      )
      userinfo_result = OidcOpUserInfoClient::Result.new(
        success: true,
        claims: { "sub" => OidcSubject.for(actor, resource_type: "operator") },
        error: nil,
        dependency_failure: false,
      )
      OidcOpUserInfoClient.stub(:call, userinfo_result) do
        browser.get(
          completion.request_uri,
          headers: {
            "Sec-Fetch-Mode" => "navigate", "Sec-Fetch-Dest" => "document", "Sec-Fetch-Site" => "same-origin",
          },
        )
      end

      assert_includes [302, 303], browser.response.status
      assert_equal 1, OperatorToken.where(staff_id: actor.id).count
      root = OperatorToken.find_by!(public_id: parent.reload.browser_session_ref)
      assert_equal actor.id, root.staff_id
      assert_equal "passkey", root.established_authentication_method
      assert_withheld { root.root_login_established_at.present? }
      assert_equal original_parent_id, parent.id
      assert_equal original_binding_id, binding.reload.id
      assert_equal original_parent_id, binding.authorization_transaction_id
    ensure
      travel_back
      ActionController::Base.allow_forgery_protection = previous_protection
      OmniAuth.config.test_mode = previous_omniauth
      TurnstileVerifierStub.enabled, TurnstileVerifierStub.response = previous_turnstile
      TurnstileVerifierStub.challenge_enabled, TurnstileVerifierStub.challenge_response = previous_challenge
    end
  end
end
# rubocop:enable Minitest/MultipleAssertions
