# typed: false
# frozen_string_literal: true

require "test_helper"

class IdentitySettingsPageCoverageTest < ActionDispatch::IntegrationTest
  # Rate-limit counters are a NullStore by default in test so unrelated tests
  # cannot accumulate them; this file asserts real limiting behavior, so it
  # opts into a deterministic MemoryStore.
  rate_limit_counters!

  fixtures :operators, :clients

  setup do
    TurnstileVerifierStub.challenge_enabled = true
    TurnstileVerifierStub.challenge_response = { "success" => true }
  end

  teardown do
    TurnstileVerifierStub.challenge_enabled = false
    TurnstileVerifierStub.challenge_response = nil
  end

  test "operator browses identity sessions secrets and telephones" do
    host = ENV.fetch("PUBLIC_BASE_STAFF_URL")
    host! host
    operator = operators(:one)
    token = OperatorToken.create!(
      authentication_epoch: 0,
      staff: operator,
      staff_token_kind_id: OperatorTokenKind::BROWSER_WEB,
      staff_token_status_id: OperatorTokenStatus::ACTIVE,
      discard_at: 1.day.from_now,
    )
    BaseSelectorBootstrapAuthority.call(surface: :org, principal: operator)
    BaseSelectorAuthority.prepare(surface: :org, principal: operator, session: token)
    _verification, raw_verification = OperatorVerification.issue_for_token!(token: token)
    cookies[OperatorVerification.cookie_name] = raw_verification
    token.update!(
      last_step_up_at: Time.current,
      last_step_up_scope: "settings_secret_credential",
      last_step_up_aal: "aal2",
      last_step_up_method: "passkey",
      last_step_up_phishing_resistant: true, last_step_up_user_verified: true,
      last_step_up_credential_ref: "test-step-up-credential", last_step_up_full_reauthentication: false,
      last_step_up_session_public_id: token.public_id,
      last_step_up_purpose: "step_up",
      last_step_up_audience: "step_up:org",
    )
    access_token = AuthenticationToken.encode(
      operator,
      host: host,
      session_public_id: token.public_id,
      resource_type: "operator",
      jwt_issuer_id: "surface:BASE_ORG",
    )
    cookies[AuthenticationBase::ACCESS_COOKIE_KEY] = access_token
    # Base pages authenticate by the Browser RP credential; the root cookie alone does not.
    begin
      rp_cookie_pairs =
        begin
          rp_host = host
          rp_token = token
          rp_client = OidcClientRegistry.find!("base-org-ww")
          rp_key = [rp_client.client_id, rp_token.public_id]
          @base_browser_rp_credentials ||= {}
          if @base_browser_rp_credentials[rp_key] ||
              (rp_token.currently_usable? &&
                !(rp_token.device_session_id && OpOrgGrant.exists?(
                  device_session_id: rp_token.device_session_id, oidc_client_id: rp_client.client_id, revoked_at: nil,
                )))
            unless @base_browser_rp_credentials[rp_key]
              rp_token.rotate_refresh_token! unless rp_token.device_session_record.current_refresh_token_id
              rp_now = Time.current
              rp_session = OpOrgGrant.create!(
                authentication_epoch: 0,
                operator_token: rp_token, oidc_client_id: rp_client.client_id, oidc_scope: "openid profile",
                oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16), oidc_auth_time: rp_now,
                refresh_token_expires_at: rp_now + 10.minutes,
              )
              rp_access = AuthenticationTokenService.encode(
                operator, host: rp_host, resource_type: "operator",
                          session_public_id: rp_token.public_id, base_session_public_id: rp_token.public_id,
                          oidc_sid: rp_session.public_id, oidc_jti: rp_session.oidc_jti,
                          expires_at: rp_now + 10.minutes, scopes: %w(openid profile),
                          issuer: OidcIssuer.for_client(rp_client), audiences: [rp_client.aud],
                          jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(rp_client),
                          subject: OidcSubject.for(operator, resource_type: "operator"), client_id: rp_client.client_id,
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
      cookies.merge(rp_cookie_pairs, URI.parse("https://#{rp_host}/"))
    end
    headers = {
      "Authorization" => "Bearer #{access_token}",
      "Accept" => "text/html,application/xhtml+xml",
      "Client-Agent" => "Mozilla/5.0",
      "Host" => host,
      "X-TEST-SESSION-PUBLIC-ID" => token.public_id,
    }

    OperatorSecretCredentialStatus.find_or_create_by!(id: OperatorSecretCredentialStatus::ACTIVE)
    OperatorSecretCredentialStatus.find_or_create_by!(id: OperatorSecretCredentialStatus::DELETED)
    OperatorSecretCredentialKind.find_or_create_by!(id: OperatorSecretCredentialKind::LOGIN)
    OperatorPasskeyStatus.find_or_create_by!(id: OperatorPasskeyStatus::ACTIVE)
    secret = OperatorSecretCredential.create!(
      staff: operator,
      name: "Org coverage secret",
      password_digest: "digest",
      staff_secret_kind_id: OperatorSecretCredentialKind::LOGIN,
      staff_secret_status_id: OperatorSecretCredentialStatus::ACTIVE,
      last_used_at: Time.current,
    )
    extra_secret = OperatorSecretCredential.create!(
      staff: operator,
      name: "Org extra secret",
      password_digest: "digest2",
      staff_secret_kind_id: OperatorSecretCredentialKind::LOGIN,
      staff_secret_status_id: OperatorSecretCredentialStatus::ACTIVE,
    )
    OperatorPasskey.create!(
      staff: operator,
      webauthn_id: "org_coverage_passkey_#{SecureRandom.hex(8)}",
      external_id: SecureRandom.uuid,
      public_key: "public_key_#{SecureRandom.hex(8)}",
      description: "Coverage passkey",
      status_id: OperatorPasskeyStatus::ACTIVE,
    )
    telephone = OperatorTelephone.create!(
      staff: operator,
      number: "+819066610001",
      staff_telephone_status_id: OperatorTelephoneStatus::VERIFIED,
    )
    extra_telephone = OperatorTelephone.create!(
      staff: operator,
      number: "+819066610002",
      staff_telephone_status_id: OperatorTelephoneStatus::UNVERIFIED,
    )

    get base_org_identity_sessions_url(ri: "jp", host: host), headers: headers

    assert_includes [200, 302, 303], response.status

    other_session = OperatorToken.where(staff: operator).where.not(id: token.id).where(
      "discard_at > ?",
      Time.current,
    ).first
    if other_session
      get base_org_identity_session_url(other_session.public_id, ri: "jp", host: host), headers: headers

      assert_includes [200, 302, 303, 406], response.status

      delete base_org_identity_session_url(other_session.public_id, ri: "jp", host: host), headers: headers

      assert_includes [200, 302, 303], response.status
    end

    get base_org_identity_secrets_url(ri: "jp", host: host), headers: headers

    assert_response :success

    get base_org_identity_secret_url(secret.public_id, ri: "jp", host: host), headers: headers

    assert_response :success

    get edit_base_org_identity_secret_url(secret.public_id, ri: "jp", host: host), headers: headers

    assert_response :success

    get new_base_org_identity_secret_url(ri: "jp", host: host), headers: headers

    assert_response :success

    post base_org_identity_secrets_url(ri: "jp", host: host),
         params: { staff_secret_credential: { name: "Created org secret", enabled: "1" } },
         headers: headers

    assert_includes [302, 303, 422], response.status

    TurnstileVerifierStub.challenge_response = { "success" => false }
    post base_org_identity_secrets_url(ri: "jp", host: host),
         params: { staff_secret_credential: { name: "Turnstile blocked org secret", enabled: "1" } },
         headers: headers

    assert_response :unprocessable_content
    assert_not OperatorSecretCredential.exists?(name: "Turnstile blocked org secret")
    TurnstileVerifierStub.challenge_response = { "success" => true }

    patch base_org_identity_secret_url(secret.public_id, ri: "jp", host: host),
          params: { staff_secret_credential: { name: "Renamed org secret", enabled: "1" } },
          headers: headers

    assert_response :redirect

    delete base_org_identity_secret_url(extra_secret.public_id, ri: "jp", host: host), headers: headers

    assert_response :redirect

    token.update!(last_step_up_scope: "settings_telephone")
    get base_org_identity_telephones_url(ri: "jp", host: host), headers: headers

    assert_response :success

    get edit_base_org_identity_telephone_url(telephone.id, ri: "jp", host: host), headers: headers

    assert_response :success

    get new_base_org_identity_telephone_url(ri: "jp", host: host), headers: headers

    assert_response :success

    post base_org_identity_telephones_url(ri: "jp", host: host),
         params: { staff_telephone: { raw_number: "" } },
         headers: headers

    assert_response :unprocessable_content

    fake_adapter = Object.new
    fake_adapter.define_singleton_method(:deliver) { |**_args| true }
    OtpAdapter.stub(:for, fake_adapter) do
      post base_org_identity_telephones_url(ri: "jp", host: host),
           params: { staff_telephone: { raw_number: "+819066610099" } },
           headers: headers
    end

    assert_includes [302, 303, 422], response.status

    delete base_org_identity_telephone_url(extra_telephone.id, ri: "jp", host: host), headers: headers

    assert_response :redirect

    operator_email = OperatorEmail.create!(
      staff: operator,
      address: "org-coverage-#{SecureRandom.hex(4)}@example.test",
      staff_email_status_id: OperatorEmailStatus::VERIFIED,
    )
    extra_operator_email = OperatorEmail.create!(
      staff: operator,
      address: "org-coverage-extra-#{SecureRandom.hex(4)}@example.test",
      staff_email_status_id: OperatorEmailStatus::UNVERIFIED,
    )

    token.update!(last_step_up_scope: "settings_email")
    get base_org_identity_emails_url(ri: "jp", host: host), headers: headers

    assert_response :success

    get edit_base_org_identity_email_url(operator_email.public_id, ri: "jp", host: host), headers: headers

    assert_response :success

    patch base_org_identity_email_url(operator_email.public_id, ri: "jp", host: host),
          params: { staff_email: { promotional: "0", notifiable: "1" } },
          headers: headers

    assert_includes [302, 303, 422], response.status

    TurnstileVerifierStub.challenge_response = { "success" => false }
    patch base_org_identity_email_url(operator_email.public_id, ri: "jp", host: host),
          params: { staff_email: { promotional: "0", notifiable: "1" } },
          headers: headers

    assert_response :unprocessable_content
    TurnstileVerifierStub.challenge_response = { "success" => true }

    delete base_org_identity_email_url(extra_operator_email.public_id, ri: "jp", host: host), headers: headers

    assert_includes [302, 303], response.status

    get new_base_org_identity_emails_registration_url(ri: "jp", host: host), headers: headers

    assert_response :success

    get edit_base_org_identity_emails_registration_url(ri: "jp", host: host), headers: headers

    assert_response :redirect

    TurnstileVerifierStub.challenge_response = { "success" => false }
    post base_org_identity_emails_registration_url(ri: "jp", host: host),
         params: { staff_email: { raw_address: "org-coverage-#{SecureRandom.hex(4)}@example.test" } },
         headers: headers

    assert_response :unprocessable_content

    TurnstileVerifierStub.challenge_response = { "success" => true }
    OtpAdapter.stub(:for, fake_adapter) do
      post base_org_identity_emails_registration_url(ri: "jp", host: host),
           params: { staff_email: { raw_address: "org-coverage-#{SecureRandom.hex(4)}@example.test" } },
           headers: headers
    end

    assert_includes [302, 303, 422], response.status

    token.update!(last_step_up_scope: "settings_telephone")
    get new_base_org_identity_telephones_registration_url(ri: "jp", host: host), headers: headers

    assert_response :success

    get edit_base_org_identity_telephones_registration_url(ri: "jp", host: host), headers: headers

    assert_includes [302, 303], response.status
  end

  test "client browses identity telephones" do
    host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    host! host
    user = clients(:one)
    token = ClientToken.create!(
      authentication_epoch: 0,
      user: user,
      user_token_kind_id: ClientTokenKind::BROWSER_WEB,
      user_token_status_id: ClientTokenStatus::ACTIVE,
      discard_at: 1.day.from_now,
    )
    BaseSelectorBootstrapAuthority.call(surface: :app, principal: user)
    BaseSelectorAuthority.prepare(surface: :app, principal: user, session: token)
    _verification, raw_verification = ClientVerification.issue_for_token!(token: token)
    cookies[ClientVerification.cookie_name] = raw_verification
    token.update!(
      last_step_up_at: Time.current,
      last_step_up_scope: "settings_telephone",
      last_step_up_aal: "aal2",
      last_step_up_method: "passkey",
      last_step_up_phishing_resistant: true, last_step_up_user_verified: true,
      last_step_up_credential_ref: "test-step-up-credential", last_step_up_full_reauthentication: false,
      last_step_up_session_public_id: token.public_id,
      last_step_up_purpose: "step_up",
      last_step_up_audience: "step_up:app",
    )
    access_token = AuthenticationToken.encode(
      user,
      host: host,
      session_public_id: token.public_id,
      resource_type: "client",
      jwt_issuer_id: "surface:BASE_APP",
    )
    cookies[AuthenticationBase::ACCESS_COOKIE_KEY] = access_token
    # Base pages authenticate by the Browser RP credential; the root cookie alone does not.
    begin
      rp_cookie_pairs =
        begin
          rp_host = host
          rp_token = token
          rp_client = OidcClientRegistry.find!("base-app-ww")
          rp_key = [rp_client.client_id, rp_token.public_id]
          @base_browser_rp_credentials ||= {}
          if @base_browser_rp_credentials[rp_key] ||
              (rp_token.currently_usable? &&
                !(rp_token.device_session_id && OpAppGrant.exists?(
                  device_session_id: rp_token.device_session_id, oidc_client_id: rp_client.client_id, revoked_at: nil,
                )))
            unless @base_browser_rp_credentials[rp_key]
              rp_token.rotate_refresh_token! unless rp_token.device_session_record.current_refresh_token_id
              rp_now = Time.current
              rp_session = OpAppGrant.create!(
                authentication_epoch: 0,
                client_token: rp_token, oidc_client_id: rp_client.client_id, oidc_scope: "openid profile",
                oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16), oidc_auth_time: rp_now,
                refresh_token_expires_at: rp_now + 10.minutes,
              )
              rp_access = AuthenticationTokenService.encode(
                user, host: rp_host, resource_type: "client",
                      session_public_id: rp_token.public_id, base_session_public_id: rp_token.public_id,
                      oidc_sid: rp_session.public_id, oidc_jti: rp_session.oidc_jti,
                      expires_at: rp_now + 10.minutes, scopes: %w(openid profile),
                      issuer: OidcIssuer.for_client(rp_client), audiences: [rp_client.aud],
                      jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(rp_client),
                      subject: OidcSubject.for(user, resource_type: "client"), client_id: rp_client.client_id,
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
      cookies.merge(rp_cookie_pairs, URI.parse("https://#{rp_host}/"))
    end
    headers = {
      "Authorization" => "Bearer #{access_token}",
      "Accept" => "text/html,application/xhtml+xml",
      "Client-Agent" => "Mozilla/5.0",
      "Host" => host,
      "X-TEST-SESSION-PUBLIC-ID" => token.public_id,
    }

    ClientEmail.create!(
      user: user,
      address: "app-coverage-#{SecureRandom.hex(4)}@example.test",
      user_email_status_id: ClientEmailStatus::VERIFIED,
      confirm_policy: true,
    ).finalize_binding!
    ClientPasskeyStatus.find_or_create_by!(id: ClientPasskeyStatus::ACTIVE)
    ClientPasskey.create!(
      user: user,
      webauthn_id: "app_coverage_passkey_#{SecureRandom.hex(8)}",
      public_key: "public_key_#{SecureRandom.hex(8)}",
      sign_count: 0,
      description: "Coverage passkey",
      status_id: ClientPasskeyStatus::ACTIVE,
    )
    telephone = ClientTelephone.create!(
      user: user,
      number: "+819077710001",
      user_telephone_status_id: ClientTelephoneStatus::VERIFIED,
    ).finalize_binding!
    extra_telephone = ClientTelephone.create!(
      user: user,
      number: "+819077710002",
      user_telephone_status_id: ClientTelephoneStatus::UNVERIFIED,
    )

    token.update!(last_step_up_scope: "settings_telephone")
    get base_app_identity_telephones_url(ri: "jp", host: host), headers: headers

    assert_includes [200, 302, 303], response.status

    get edit_base_app_identity_telephone_url(telephone.public_id, ri: "jp", host: host), headers: headers

    assert_includes [200, 302, 303, 406], response.status

    fake_adapter = Object.new
    fake_adapter.define_singleton_method(:deliver) { |**_args| true }
    OtpAdapter.stub(:for, fake_adapter) do
      post base_app_identity_telephones_url(ri: "jp", host: host),
           params: { user_telephone: { raw_number: "+819077710099" } },
           headers: headers
    end

    assert_includes [302, 303, 422], response.status

    delete base_app_identity_telephone_url(extra_telephone.public_id, ri: "jp", host: host), headers: headers

    assert_response :unauthorized
  end
end
