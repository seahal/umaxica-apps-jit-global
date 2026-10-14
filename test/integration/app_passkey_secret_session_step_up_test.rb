# frozen_string_literal: true

require "test_helper"

class AppPasskeySecretSessionStepUpTest < ActionDispatch::IntegrationTest
  setup do
    TurnstileVerifierStub.enabled = true
    TurnstileVerifierStub.response = { "success" => true }
  end

  teardown do
    TurnstileVerifierStub.enabled = false
    TurnstileVerifierStub.response = nil
  end

  test "additional TOTP registration starts with a read-only Base form and purpose-bound POST" do
    protection = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true
    base_host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    actor = Client.create!(status_id: ClientStatus::ACTIVE)
    token = ClientToken.create!(user: actor, root_login_established_at: ClientToken.database_now)
    passkey = actor.client_passkeys.create!(webauthn_id: SecureRandom.hex(32), public_key: "public-key")
    BaseSelectorBootstrapAuthority.call(surface: :app, principal: actor)
    BaseSelectorAuthority.prepare(surface: :app, principal: actor, session: token)
    token.update!(
      last_step_up_at: ClientToken.database_now, last_step_up_scope: "settings_totp",
      last_step_up_method: "passkey", last_step_up_session_public_id: token.public_id,
      last_step_up_purpose: "step_up", last_step_up_audience: "step_up:app",
      last_step_up_phishing_resistant: true, last_step_up_user_verified: true,
      last_step_up_credential_ref: passkey.public_id, last_step_up_full_reauthentication: false,
    )
    base = open_session
    base.host!(base_host)
    base.https!
    begin
      rp_cookie_pairs =
        begin
          rp_host = base_host
          rp_token = token
          rp_client = OidcClientRegistry.find!("base-app-ww")
          rp_key = [rp_client.client_id, rp_token.public_id]
          @base_browser_rp_credentials ||= {}
          if @base_browser_rp_credentials[rp_key] ||
              (rp_token.currently_usable? &&
                !(rp_token.device_session_id && ClientRpSession.exists?(
                  device_session_id: rp_token.device_session_id, oidc_client_id: rp_client.client_id, revoked_at: nil,
                )))
            unless @base_browser_rp_credentials[rp_key]
              rp_token.rotate_refresh_token! unless rp_token.device_session_record.current_refresh_token_id
              rp_now = Time.current
              rp_session = ClientRpSession.create!(
                client_token: rp_token, oidc_client_id: rp_client.client_id, oidc_scope: "openid profile",
                oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16), oidc_auth_time: rp_now,
                refresh_token_expires_at: rp_now + 10.minutes,
              )
              rp_access = AuthenticationTokenService.encode(
                actor, host: rp_host, resource_type: "client",
                       session_public_id: rp_token.public_id, base_session_public_id: rp_token.public_id,
                       oidc_sid: rp_session.public_id, oidc_jti: rp_session.oidc_jti,
                       expires_at: rp_now + 10.minutes, scopes: %w(openid profile),
                       issuer: OidcIssuer.for_client(rp_client), audiences: [rp_client.aud],
                       jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(rp_client),
                       subject: OidcSubject.for(actor, resource_type: "client"), client_id: rp_client.client_id,
              )
              @base_browser_rp_credentials[rp_key] = [rp_access, rp_session.issue_refresh_token!]
            end
            rp_access, rp_refresh = @base_browser_rp_credentials.fetch(rp_key)
            [
              "#{OidcRpBrowserCredentialContract::ACCESS_COOKIE}=#{Rack::Utils.escape(rp_access)}",
              "#{OidcRpBrowserCredentialContract::REFRESH_COOKIE}=#{Rack::Utils.escape(rp_refresh)}",
            ]
          else
            []
          end
        end
      base.cookies.merge(rp_cookie_pairs, URI.parse("https://#{rp_host}/"))
    end
    headers = { "Origin" => "https://#{base_host}", "Sec-Fetch-Site" => "same-origin" }
    assert_no_difference("ClientAuthAdmissionBinding.count") do
      base.get(new_base_app_identity_totp_path(ri: "jp"), headers: headers)
    end

    assert_equal 200, base.response.status
    csrf = base.response.parsed_body.at_css('input[name="authenticity_token"]')["value"]
    assert_difference("ClientAuthAdmissionBinding.count", 1) do
      base.post(base_app_identity_totps_path(ri: "jp"), params: { authenticity_token: csrf }, headers: headers)
    end

    assert_equal 303, base.response.status, base.response.body
    entry_uri = URI.parse(base.response.location)

    assert_equal [ENV.fetch("PUBLIC_AUTH_SERVICE_URL"), new_auth_app_settings_totp_path],
                 [entry_uri.host, entry_uri.path]
    reference = Rack::Utils.parse_query(entry_uri.query).fetch("entry_ref")
    binding = ClientAuthAdmissionBinding.find_by!(entry_ref: reference)

    assert_equal ["credential_registration_handoff", ["totp"], token.id, 0],
                 [binding.purpose,
                  ClientStepUpCeremonyTransaction.find(binding.step_up_ceremony_transaction_id).allowed_methods_array,
                  binding.base_token_id, actor.client_totp_credentials.count,]
    auth = open_session
    auth.host!(ENV.fetch("PUBLIC_AUTH_SERVICE_URL"))
    auth.https!
    auth.get(entry_uri.to_s)

    assert_equal [200, "/ceremony_bindings", nil],
                 [auth.response.status, URI.parse(auth.response.parsed_body.at_css("form")["action"]).path,
                  binding.reload.auth_ceremony_session_id,]
    csrf = auth.response.parsed_body.at_css('input[name="authenticity_token"]')["value"]
    auth_headers = {
      "Origin" => "https://#{ENV.fetch("PUBLIC_AUTH_SERVICE_URL")}", "Sec-Fetch-Site" => "same-origin",
    }
    auth.post(
      "/ceremony_bindings", params: { entry_ref: reference, authenticity_token: csrf, ri: "jp" },
                            headers: auth_headers,
    )

    assert_equal 303, auth.response.status
    confirmation_url = auth.response.location
    root_headers =
      begin
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
            rp_token.rotate_refresh_token! unless rp_token.device_session_record.current_refresh_token_id
            rp_now = Time.current
            rp_session = ClientRpSession.create!(
              client_token: rp_token, oidc_client_id: rp_client.client_id, oidc_scope: "openid profile",
              oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16), oidc_auth_time: rp_now,
              refresh_token_expires_at: rp_now + 10.minutes,
            )
            rp_access = AuthenticationTokenService.encode(
              rp_token.actor_record, host: rp_host, resource_type: "client",
                                     session_public_id: rp_token.public_id, base_session_public_id: rp_token.public_id,
                                     oidc_sid: rp_session.public_id, oidc_jti: rp_session.oidc_jti,
                                     expires_at: rp_now + 10.minutes, scopes: %w(openid profile),
                                     issuer: OidcIssuer.for_client(rp_client), audiences: [rp_client.aud],
                                     jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(rp_client),
                                     subject: OidcSubject.for(
                                       rp_token.actor_record,
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
    base.cookies[AuthenticationBase::ACCESS_COOKIE_KEY] = root_headers.fetch("Authorization").delete_prefix("Bearer ")
    base.get(confirmation_url)

    assert_equal 200, base.response.status
    assert_nil binding.reload.base_confirmed_at
    csrf = base.response.parsed_body.at_css('input[name="authenticity_token"]')["value"]
    base.post(confirmation_url, params: { authenticity_token: csrf, ri: "jp" }, headers: headers)

    assert_equal [303, true, new_auth_app_settings_totp_path],
                 [base.response.status, binding.reload.confirmed?, URI.parse(base.response.location).path]
    auth.get(base.response.location)

    assert_equal 200, auth.response.status
    csrf = auth.response.parsed_body.at_css('input[name="authenticity_token"]')["value"]
    assert_no_difference("IdentityTotpCeremonyCandidate.count") do
      auth.post(
        auth_app_settings_totps_path(ri: "jp"),
        params: { entry_ref: reference, authenticity_token: csrf }, headers: auth_headers,
      )
    end

    assert_equal 303, auth.response.status
    assert_predicate binding.reload, :redeemed?
    assert_equal new_auth_app_settings_totp_url(
      ri: "jp", host: ENV.fetch("PUBLIC_AUTH_SERVICE_URL"), protocol: "https",
    ), auth.response.location
    assert_not_includes auth.response.location, "entry_ref"
    assert_equal 0, actor.client_totp_credentials.count
    foreign_base = open_session
    foreign_base.host!(base_host)
    foreign_base.https!
    begin
      rp_cookie_pairs =
        begin
          rp_host = base_host
          rp_token = token
          rp_client = OidcClientRegistry.find!("base-app-ww")
          rp_key = [rp_client.client_id, rp_token.public_id]
          @base_browser_rp_credentials ||= {}
          if @base_browser_rp_credentials[rp_key] ||
              (rp_token.currently_usable? &&
                !(rp_token.device_session_id && ClientRpSession.exists?(
                  device_session_id: rp_token.device_session_id, oidc_client_id: rp_client.client_id, revoked_at: nil,
                )))
            unless @base_browser_rp_credentials[rp_key]
              rp_token.rotate_refresh_token! unless rp_token.device_session_record.current_refresh_token_id
              rp_now = Time.current
              rp_session = ClientRpSession.create!(
                client_token: rp_token, oidc_client_id: rp_client.client_id, oidc_scope: "openid profile",
                oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16), oidc_auth_time: rp_now,
                refresh_token_expires_at: rp_now + 10.minutes,
              )
              rp_access = AuthenticationTokenService.encode(
                actor, host: rp_host, resource_type: "client",
                       session_public_id: rp_token.public_id, base_session_public_id: rp_token.public_id,
                       oidc_sid: rp_session.public_id, oidc_jti: rp_session.oidc_jti,
                       expires_at: rp_now + 10.minutes, scopes: %w(openid profile),
                       issuer: OidcIssuer.for_client(rp_client), audiences: [rp_client.aud],
                       jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(rp_client),
                       subject: OidcSubject.for(actor, resource_type: "client"), client_id: rp_client.client_id,
              )
              @base_browser_rp_credentials[rp_key] = [rp_access, rp_session.issue_refresh_token!]
            end
            rp_access, rp_refresh = @base_browser_rp_credentials.fetch(rp_key)
            [
              "#{OidcRpBrowserCredentialContract::ACCESS_COOKIE}=#{Rack::Utils.escape(rp_access)}",
              "#{OidcRpBrowserCredentialContract::REFRESH_COOKIE}=#{Rack::Utils.escape(rp_refresh)}",
            ]
          else
            []
          end
        end
      foreign_base.cookies.merge(rp_cookie_pairs, URI.parse("https://#{rp_host}/"))
    end
    count = ClientAuthAdmissionBinding.count
    foreign_base.get(new_base_app_identity_totp_path(ri: "jp"), params: { restart_of: reference }, headers: headers)

    assert_equal [400, nil, count, nil],
                 [foreign_base.response.status, foreign_base.response.location, ClientAuthAdmissionBinding.count,
                  binding.reload.retired_at,]
    base.get(new_base_app_identity_passkey_path(ri: "jp"), params: { restart_of: reference }, headers: headers)

    assert_equal [400, nil, nil],
                 [base.response.status, base.response.location, binding.reload.retired_at]
    base.get(new_base_app_identity_totp_path(ri: "jp"), params: { restart_of: reference }, headers: headers)

    assert_equal 200, base.response.status
    restart_field = base.response.parsed_body.at_css('input[name="restart_of"]')

    assert_equal reference, restart_field&.[]("value")
    assert_equal I18n.t("actions.cancel_and_start"), base.response.parsed_body.at_css('button[type="submit"]').text
    csrf = base.response.parsed_body.at_css('input[name="authenticity_token"]')["value"]
    previous_parent = ClientStepUpCeremonyTransaction.find(binding.step_up_ceremony_transaction_id)
    base.post(
      base_app_identity_totps_path(ri: "jp"),
      params: { authenticity_token: csrf, restart_of: restart_field["value"] }, headers: headers,
    )

    assert_equal 303, base.response.status
    replacement_ref = Rack::Utils.parse_query(URI.parse(base.response.location).query).fetch("entry_ref")

    assert_not_equal reference, replacement_ref
    assert_equal "canceled", previous_parent.reload.status
    replacement_binding = ClientAuthAdmissionBinding.find_by!(entry_ref: replacement_ref)
    replacement_parent = ClientStepUpCeremonyTransaction.find(replacement_binding.step_up_ceremony_transaction_id)

    assert_equal ["pending", 0], [replacement_parent.status, ClientTotpCredential.where(user_id: actor.id).count]
  ensure
    ActionController::Base.allow_forgery_protection = protection
  end

  test "a Secret session cannot start Base passkey registration without an independent Step-Up" do
    base_host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    actor = Client.create!(status_id: ClientStatus::ACTIVE)
    token = ClientToken.create!(
      user: actor, established_authentication_method: "secret", root_login_established_at: ClientToken.database_now,
    )
    BaseSelectorBootstrapAuthority.call(surface: :app, principal: actor)
    BaseSelectorAuthority.prepare(surface: :app, principal: actor, session: token)
    base = open_session
    base.host!(base_host)
    base.https!
    begin
      rp_cookie_pairs =
        begin
          rp_host = base_host
          rp_token = token
          rp_client = OidcClientRegistry.find!("base-app-ww")
          rp_key = [rp_client.client_id, rp_token.public_id]
          @base_browser_rp_credentials ||= {}
          if @base_browser_rp_credentials[rp_key] ||
              (rp_token.currently_usable? &&
                !(rp_token.device_session_id && ClientRpSession.exists?(
                  device_session_id: rp_token.device_session_id, oidc_client_id: rp_client.client_id, revoked_at: nil,
                )))
            unless @base_browser_rp_credentials[rp_key]
              rp_token.rotate_refresh_token! unless rp_token.device_session_record.current_refresh_token_id
              rp_now = Time.current
              rp_session = ClientRpSession.create!(
                client_token: rp_token, oidc_client_id: rp_client.client_id, oidc_scope: "openid profile",
                oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16), oidc_auth_time: rp_now,
                refresh_token_expires_at: rp_now + 10.minutes,
              )
              rp_access = AuthenticationTokenService.encode(
                actor, host: rp_host, resource_type: "client",
                       session_public_id: rp_token.public_id, base_session_public_id: rp_token.public_id,
                       oidc_sid: rp_session.public_id, oidc_jti: rp_session.oidc_jti,
                       expires_at: rp_now + 10.minutes, scopes: %w(openid profile),
                       issuer: OidcIssuer.for_client(rp_client), audiences: [rp_client.aud],
                       jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(rp_client),
                       subject: OidcSubject.for(actor, resource_type: "client"), client_id: rp_client.client_id,
              )
              @base_browser_rp_credentials[rp_key] = [rp_access, rp_session.issue_refresh_token!]
            end
            rp_access, rp_refresh = @base_browser_rp_credentials.fetch(rp_key)
            [
              "#{OidcRpBrowserCredentialContract::ACCESS_COOKIE}=#{Rack::Utils.escape(rp_access)}",
              "#{OidcRpBrowserCredentialContract::REFRESH_COOKIE}=#{Rack::Utils.escape(rp_refresh)}",
            ]
          else
            []
          end
        end
      base.cookies.merge(rp_cookie_pairs, URI.parse("https://#{rp_host}/"))
    end
    headers = {
      "Host" => base_host, "Origin" => "https://#{base_host}", "Sec-Fetch-Site" => "same-origin",
    }

    assert_no_difference("ClientStepUpCeremonyTransaction.count") do
      base.get(new_base_app_identity_passkey_path(ri: "jp"), headers: headers)
    end

    assert_equal 200, base.response.status
    csrf = base.response.parsed_body.at_css('input[name="authenticity_token"]')["value"]
    assert_no_difference("ClientStepUpCeremonyTransaction.count") do
      base.post(base_app_identity_passkeys_path(ri: "jp"), params: { authenticity_token: csrf }, headers: headers)
    end

    assert_equal 400, base.response.status
    assert_nil base.response.headers["Location"]
    assert_equal 0, actor.client_passkeys.count
    assert_nil token.reload.last_step_up_at
  end

  test "a Secret-origin session with a valid other-method Step-Up reaches the admitted Auth registration" do
    base_host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    auth_host = ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
    actor = Client.create!(status_id: ClientStatus::ACTIVE)
    passkey = actor.client_passkeys.create!(webauthn_id: "secret-session-step-up-passkey", public_key: "public-key")
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
      last_step_up_credential_ref: passkey.public_id, last_step_up_full_reauthentication: false,
    )
    base = open_session
    base.host!(base_host)
    base.https!
    begin
      rp_cookie_pairs =
        begin
          rp_host = base_host
          rp_token = token
          rp_client = OidcClientRegistry.find!("base-app-ww")
          rp_key = [rp_client.client_id, rp_token.public_id]
          @base_browser_rp_credentials ||= {}
          if @base_browser_rp_credentials[rp_key] ||
              (rp_token.currently_usable? &&
                !(rp_token.device_session_id && ClientRpSession.exists?(
                  device_session_id: rp_token.device_session_id, oidc_client_id: rp_client.client_id, revoked_at: nil,
                )))
            unless @base_browser_rp_credentials[rp_key]
              rp_token.rotate_refresh_token! unless rp_token.device_session_record.current_refresh_token_id
              rp_now = Time.current
              rp_session = ClientRpSession.create!(
                client_token: rp_token, oidc_client_id: rp_client.client_id, oidc_scope: "openid profile",
                oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16), oidc_auth_time: rp_now,
                refresh_token_expires_at: rp_now + 10.minutes,
              )
              rp_access = AuthenticationTokenService.encode(
                actor, host: rp_host, resource_type: "client",
                       session_public_id: rp_token.public_id, base_session_public_id: rp_token.public_id,
                       oidc_sid: rp_session.public_id, oidc_jti: rp_session.oidc_jti,
                       expires_at: rp_now + 10.minutes, scopes: %w(openid profile),
                       issuer: OidcIssuer.for_client(rp_client), audiences: [rp_client.aud],
                       jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(rp_client),
                       subject: OidcSubject.for(actor, resource_type: "client"), client_id: rp_client.client_id,
              )
              @base_browser_rp_credentials[rp_key] = [rp_access, rp_session.issue_refresh_token!]
            end
            rp_access, rp_refresh = @base_browser_rp_credentials.fetch(rp_key)
            [
              "#{OidcRpBrowserCredentialContract::ACCESS_COOKIE}=#{Rack::Utils.escape(rp_access)}",
              "#{OidcRpBrowserCredentialContract::REFRESH_COOKIE}=#{Rack::Utils.escape(rp_refresh)}",
            ]
          else
            []
          end
        end
      base.cookies.merge(rp_cookie_pairs, URI.parse("https://#{rp_host}/"))
    end
    headers = {
      "Host" => base_host, "Origin" => "https://#{base_host}", "Sec-Fetch-Site" => "same-origin",
    }

    assert_no_difference("ClientAuthAdmissionBinding.count") do
      base.get(new_base_app_identity_passkey_path(ri: "jp"), headers: headers)
    end

    assert_equal 200, base.response.status
    csrf = base.response.parsed_body.at_css('input[name="authenticity_token"]')["value"]
    base.post(base_app_identity_passkeys_path(ri: "jp"), params: { authenticity_token: csrf }, headers: headers)

    assert_equal 303, base.response.status, base.response.body
    registration_uri = URI.parse(base.response.location)

    assert_equal auth_host, registration_uri.host
    assert_equal new_auth_app_verification_registration_passkey_path,
                 registration_uri.path
    assert_match AuthAdmissionBinding::REFERENCE_PATTERN,
                 Rack::Utils.parse_query(registration_uri.query).fetch("entry_ref")
    assert_equal 1, actor.client_passkeys.count
    assert_equal "passkey", token.reload.last_step_up_method
  end
end
