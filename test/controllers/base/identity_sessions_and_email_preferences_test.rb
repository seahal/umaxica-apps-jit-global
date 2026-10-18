# typed: false
# frozen_string_literal: true

require "test_helper"

# Session inspection and revocation on the corporate identity surface, and the
# email-preference update on the app identity surface, including its Turnstile
# rejection branch.
class BaseIdentitySessionsAndEmailPreferencesTest < ActionDispatch::IntegrationTest
  fixtures :clients, :client_statuses, :client_email_statuses,
           :client_token_kinds, :client_token_statuses, :client_token_binding_methods,
           :client_token_dbsc_statuses,
           :visitors, :visitor_statuses, :visitor_token_kinds, :visitor_token_statuses,
           :visitor_token_binding_methods, :visitor_token_dbsc_statuses

  setup do
    TurnstileVerifierStub.challenge_enabled = true
    TurnstileVerifierStub.challenge_response = { "success" => true }
  end

  teardown do
    TurnstileVerifierStub.challenge_enabled = false
    TurnstileVerifierStub.challenge_response = nil
  end

  test "com session detail page describes a session the visitor owns" do
    host = ENV.fetch("PUBLIC_BASE_CORPORATE_URL")
    host! host
    visitor = visitors(:reserved_visitor)
    token = VisitorToken.create!(
      visitor: visitor, visitor_token_kind_id: VisitorTokenKind::BROWSER_WEB,
      visitor_token_status_id: VisitorTokenStatus::ACTIVE, discard_at: 1.day.from_now,
    )
    other_session = VisitorToken.create!(
      visitor: visitor, visitor_token_kind_id: VisitorTokenKind::BROWSER_WEB,
      visitor_token_status_id: VisitorTokenStatus::ACTIVE, discard_at: 1.day.from_now,
    )
    BaseSelectorBootstrapAuthority.call(surface: :com, principal: visitor)
    BaseSelectorAuthority.prepare(surface: :com, principal: visitor, session: token)
    access_token = AuthenticationToken.encode(
      visitor, host: host, session_public_id: token.public_id,
               resource_type: "visitor", jwt_issuer_id: "surface:BASE_COM",
    )
    cookies[AuthenticationBase::ACCESS_COOKIE_KEY] = access_token
    # Base pages authenticate by the Browser RP credential; the root cookie alone does not.
    begin
      rp_cookie_pairs =
        begin
          rp_host = host
          rp_token = token
          rp_client = OidcClientRegistry.find!("base-com-ww")
          rp_key = [rp_client.client_id, rp_token.public_id]
          @base_browser_rp_credentials ||= {}
          if @base_browser_rp_credentials[rp_key] ||
              (rp_token.currently_usable? &&
                !(rp_token.device_session_id && OpComGrant.exists?(
                  device_session_id: rp_token.device_session_id, oidc_client_id: rp_client.client_id, revoked_at: nil,
                )))
            unless @base_browser_rp_credentials[rp_key]
              rp_token.rotate_refresh_token! unless rp_token.device_session_record.current_refresh_token_id
              rp_now = Time.current
              rp_session = OpComGrant.create!(
                visitor_token: rp_token, oidc_client_id: rp_client.client_id, oidc_scope: "openid profile",
                oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16), oidc_auth_time: rp_now,
                refresh_token_expires_at: rp_now + 10.minutes,
              )
              rp_access = AuthenticationTokenService.encode(
                visitor, host: rp_host, resource_type: "visitor",
                         session_public_id: rp_token.public_id, base_session_public_id: rp_token.public_id,
                         oidc_sid: rp_session.public_id, oidc_jti: rp_session.oidc_jti,
                         expires_at: rp_now + 10.minutes, scopes: %w(openid profile),
                         issuer: OidcIssuer.for_client(rp_client), audiences: [rp_client.aud],
                         jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(rp_client),
                         subject: OidcSubject.for(visitor, resource_type: "visitor"), client_id: rp_client.client_id,
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

    get base_com_identity_session_url(other_session.public_id, ri: "jp", host: host),
        headers: {
          "Authorization" => "Bearer #{access_token}",
          "Client-Agent" => "Mozilla/5.0",
          "Host" => host,
          "X-TEST-SESSION-PUBLIC-ID" => token.public_id,
        }

    assert_response :success
  end

  test "com session revocation revokes another session and keeps the current one" do
    host = ENV.fetch("PUBLIC_BASE_CORPORATE_URL")
    host! host
    visitor = visitors(:reserved_visitor)
    token = VisitorToken.create!(
      visitor: visitor, visitor_token_kind_id: VisitorTokenKind::BROWSER_WEB,
      visitor_token_status_id: VisitorTokenStatus::ACTIVE, discard_at: 1.day.from_now,
    )
    other_session = VisitorToken.create!(
      visitor: visitor, visitor_token_kind_id: VisitorTokenKind::BROWSER_WEB,
      visitor_token_status_id: VisitorTokenStatus::ACTIVE, discard_at: 1.day.from_now,
    )
    BaseSelectorBootstrapAuthority.call(surface: :com, principal: visitor)
    BaseSelectorAuthority.prepare(surface: :com, principal: visitor, session: token)
    access_token = AuthenticationToken.encode(
      visitor, host: host, session_public_id: token.public_id,
               resource_type: "visitor", jwt_issuer_id: "surface:BASE_COM",
    )
    cookies[AuthenticationBase::ACCESS_COOKIE_KEY] = access_token
    # Base pages authenticate by the Browser RP credential; the root cookie alone does not.
    begin
      rp_cookie_pairs =
        begin
          rp_host = host
          rp_token = token
          rp_client = OidcClientRegistry.find!("base-com-ww")
          rp_key = [rp_client.client_id, rp_token.public_id]
          @base_browser_rp_credentials ||= {}
          if @base_browser_rp_credentials[rp_key] ||
              (rp_token.currently_usable? &&
                !(rp_token.device_session_id && OpComGrant.exists?(
                  device_session_id: rp_token.device_session_id, oidc_client_id: rp_client.client_id, revoked_at: nil,
                )))
            unless @base_browser_rp_credentials[rp_key]
              rp_token.rotate_refresh_token! unless rp_token.device_session_record.current_refresh_token_id
              rp_now = Time.current
              rp_session = OpComGrant.create!(
                visitor_token: rp_token, oidc_client_id: rp_client.client_id, oidc_scope: "openid profile",
                oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16), oidc_auth_time: rp_now,
                refresh_token_expires_at: rp_now + 10.minutes,
              )
              rp_access = AuthenticationTokenService.encode(
                visitor, host: rp_host, resource_type: "visitor",
                         session_public_id: rp_token.public_id, base_session_public_id: rp_token.public_id,
                         oidc_sid: rp_session.public_id, oidc_jti: rp_session.oidc_jti,
                         expires_at: rp_now + 10.minutes, scopes: %w(openid profile),
                         issuer: OidcIssuer.for_client(rp_client), audiences: [rp_client.aud],
                         jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(rp_client),
                         subject: OidcSubject.for(visitor, resource_type: "visitor"), client_id: rp_client.client_id,
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

    delete base_com_identity_session_url(other_session.public_id, ri: "jp", host: host),
           headers: {
             "Authorization" => "Bearer #{access_token}",
             "Client-Agent" => "Mozilla/5.0",
             "Host" => host,
             "X-TEST-SESSION-PUBLIC-ID" => token.public_id,
           }

    assert_response :see_other
    assert_predicate other_session.reload, :revoked?
    assert_not token.reload.revoked?
  end

  test "app email preference update saves the new notification setting" do
    host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    host! host
    client = clients(:one)
    email = ClientEmail.create!(
      user: client, address: "app_email_preference@example.com", confirm_policy: "1",
      user_email_status_id: ClientEmailStatus::VERIFIED, notifiable: false,
    )
    token = ClientToken.create!(
      user: client, user_token_kind_id: ClientTokenKind::BROWSER_WEB,
      user_token_status_id: ClientTokenStatus::ACTIVE, discard_at: 1.day.from_now,
    )
    BaseSelectorBootstrapAuthority.call(surface: :app, principal: client)
    BaseSelectorAuthority.prepare(surface: :app, principal: client, session: token)
    actor = token.user
    scope = "settings_email"
    token.rotate_refresh_token! unless token.device_session.current_refresh_token_id
    credential = actor.client_totp_credentials.find_by(
      user_identity_totp_credential_status_id: ClientTotpCredentialStatus::ACTIVE,
    ) || ClientTotpCredential.create_for_user!(
      user: actor, user_identity_totp_credential_status_id: ClientTotpCredentialStatus::ACTIVE,
    )
    requirement = StepUpRequirement.new(
      step_up_required: true, scope: scope, allowed_methods: [:totp],
      phishing_resistant_required: false, user_verification_required: false, full_reauthentication_required: false,
      ttl: 15.minutes, purpose: "step_up", audience: "step_up:app", session_binding: token.public_id,
      token_binding: token.public_id, require_session_binding: true, actor_ref: actor.public_id,
      resource_ref: nil, tenant_ref: nil,
    )
    nonce = SecureRandom.urlsafe_base64(32)
    issuance = BaseStepUpAdmissionIssuer.call!(
      actor: actor, token: token, requirement: requirement,
      return_to: (scope == "settings_email") ? "/identity/emails" : "/settings/google",
      base_browser_nonce: nonce, base_token: token,
    )
    transaction = issuance.transaction
    binding = BaseAuthAdmissionCoordinator.find_admission_binding!(surface: "app", reference: issuance.reference)
    attached, raw_sid = ClientAuthCeremonySession.issue!
    binding.attach_auth_session!(auth_session: attached, confirmation_ref: SecureRandom.uuid)
    digest = AuthAdmissionBinding.browser_digest(surface: "app", entry_ref: issuance.reference, nonce: nonce)
    binding.confirm_base!(base_token: token, browser_digest: digest)
    BaseAuthAdmissionCoordinator.consume_entry_reference!(
      reference: issuance.reference, surface: "app", expected_intent: "step_up", binding: binding,
      raw_auth_sid: raw_sid,
    )
    admitted, = ClientAuthCeremonySession.rotate_and_admit!(
      admission_purpose: "step_up_handoff", previous_raw_sid: raw_sid,
      step_up_ceremony_transaction_ref: transaction.transaction_id,
    )
    binding.redeem!(auth_session: attached, admitted_auth_session: admitted)
    # This fixture exercises Social authorization; TOTP code verification has its own public-boundary tests.
    transaction.record_verification!(
      method: "totp", aal: "aal1", phishing_resistant: false, user_verified: false,
      verified_at: transaction.class.database_now, verified_credential_ref: credential.public_id,
    )
    proof = BaseAuthAdmissionCoordinator.issue_result!(transaction: transaction, ceremony_session_ref: admitted.id.to_s)
    IdentityStepUpCeremonyFreshnessCommitter.call!(
      actor: actor, token: token, transaction: transaction, requirement: requirement, result_reference: proof.reference,
    )

    assert_not_nil token.reload.last_step_up_at
    access_token = AuthenticationToken.encode(
      client, host: host, session_public_id: token.public_id,
              resource_type: "client", jwt_issuer_id: "surface:BASE_APP",
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
                client_token: rp_token, oidc_client_id: rp_client.client_id, oidc_scope: "openid profile",
                oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16), oidc_auth_time: rp_now,
                refresh_token_expires_at: rp_now + 10.minutes,
              )
              rp_access = AuthenticationTokenService.encode(
                client, host: rp_host, resource_type: "client",
                        session_public_id: rp_token.public_id, base_session_public_id: rp_token.public_id,
                        oidc_sid: rp_session.public_id, oidc_jti: rp_session.oidc_jti,
                        expires_at: rp_now + 10.minutes, scopes: %w(openid profile),
                        issuer: OidcIssuer.for_client(rp_client), audiences: [rp_client.aud],
                        jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(rp_client),
                        subject: OidcSubject.for(client, resource_type: "client"), client_id: rp_client.client_id,
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

    assert_not_nil token.reload.last_step_up_at
    assert_equal token.id, token.device_session.current_refresh_token_id
    patch base_app_identity_email_url(email.public_id, ri: "jp", host: host),
          params: { user_email: { notifiable: "1" } },
          headers: {
            "Authorization" => "Bearer #{access_token}",
            "Client-Agent" => "Mozilla/5.0",
            "Host" => host,
            "X-TEST-SESSION-PUBLIC-ID" => token.public_id,
          }

    assert_response :see_other
    assert_predicate email.reload, :notifiable?
  end

  test "app email preference update is rejected when the stealth Turnstile check fails" do
    host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    host! host
    client = clients(:one)
    email = ClientEmail.create!(
      user: client, address: "app_email_preference_turnstile@example.com", confirm_policy: "1",
      user_email_status_id: ClientEmailStatus::VERIFIED, notifiable: false,
    )
    token = ClientToken.create!(
      user: client, user_token_kind_id: ClientTokenKind::BROWSER_WEB,
      user_token_status_id: ClientTokenStatus::ACTIVE, discard_at: 1.day.from_now,
    )
    BaseSelectorBootstrapAuthority.call(surface: :app, principal: client)
    BaseSelectorAuthority.prepare(surface: :app, principal: client, session: token)
    actor = token.user
    scope = "settings_email"
    token.rotate_refresh_token! unless token.device_session.current_refresh_token_id
    credential = actor.client_totp_credentials.find_by(
      user_identity_totp_credential_status_id: ClientTotpCredentialStatus::ACTIVE,
    ) || ClientTotpCredential.create_for_user!(
      user: actor, user_identity_totp_credential_status_id: ClientTotpCredentialStatus::ACTIVE,
    )
    requirement = StepUpRequirement.new(
      step_up_required: true, scope: scope, allowed_methods: [:totp],
      phishing_resistant_required: false, user_verification_required: false, full_reauthentication_required: false,
      ttl: 15.minutes, purpose: "step_up", audience: "step_up:app", session_binding: token.public_id,
      token_binding: token.public_id, require_session_binding: true, actor_ref: actor.public_id,
      resource_ref: nil, tenant_ref: nil,
    )
    nonce = SecureRandom.urlsafe_base64(32)
    issuance = BaseStepUpAdmissionIssuer.call!(
      actor: actor, token: token, requirement: requirement,
      return_to: (scope == "settings_email") ? "/identity/emails" : "/settings/google",
      base_browser_nonce: nonce, base_token: token,
    )
    transaction = issuance.transaction
    binding = BaseAuthAdmissionCoordinator.find_admission_binding!(surface: "app", reference: issuance.reference)
    attached, raw_sid = ClientAuthCeremonySession.issue!
    binding.attach_auth_session!(auth_session: attached, confirmation_ref: SecureRandom.uuid)
    digest = AuthAdmissionBinding.browser_digest(surface: "app", entry_ref: issuance.reference, nonce: nonce)
    binding.confirm_base!(base_token: token, browser_digest: digest)
    BaseAuthAdmissionCoordinator.consume_entry_reference!(
      reference: issuance.reference, surface: "app", expected_intent: "step_up", binding: binding,
      raw_auth_sid: raw_sid,
    )
    admitted, = ClientAuthCeremonySession.rotate_and_admit!(
      admission_purpose: "step_up_handoff", previous_raw_sid: raw_sid,
      step_up_ceremony_transaction_ref: transaction.transaction_id,
    )
    binding.redeem!(auth_session: attached, admitted_auth_session: admitted)
    # This fixture exercises Social authorization; TOTP code verification has its own public-boundary tests.
    transaction.record_verification!(
      method: "totp", aal: "aal1", phishing_resistant: false, user_verified: false,
      verified_at: transaction.class.database_now, verified_credential_ref: credential.public_id,
    )
    proof = BaseAuthAdmissionCoordinator.issue_result!(transaction: transaction, ceremony_session_ref: admitted.id.to_s)
    IdentityStepUpCeremonyFreshnessCommitter.call!(
      actor: actor, token: token, transaction: transaction, requirement: requirement, result_reference: proof.reference,
    )

    assert_not_nil token.reload.last_step_up_at
    access_token = AuthenticationToken.encode(
      client, host: host, session_public_id: token.public_id,
              resource_type: "client", jwt_issuer_id: "surface:BASE_APP",
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
                client_token: rp_token, oidc_client_id: rp_client.client_id, oidc_scope: "openid profile",
                oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16), oidc_auth_time: rp_now,
                refresh_token_expires_at: rp_now + 10.minutes,
              )
              rp_access = AuthenticationTokenService.encode(
                client, host: rp_host, resource_type: "client",
                        session_public_id: rp_token.public_id, base_session_public_id: rp_token.public_id,
                        oidc_sid: rp_session.public_id, oidc_jti: rp_session.oidc_jti,
                        expires_at: rp_now + 10.minutes, scopes: %w(openid profile),
                        issuer: OidcIssuer.for_client(rp_client), audiences: [rp_client.aud],
                        jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(rp_client),
                        subject: OidcSubject.for(client, resource_type: "client"), client_id: rp_client.client_id,
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
    TurnstileVerifierStub.challenge_response = { "success" => false }

    assert_not_nil token.reload.last_step_up_at
    assert_equal token.id, token.device_session.current_refresh_token_id
    patch base_app_identity_email_url(email.public_id, ri: "jp", host: host),
          params: { user_email: { notifiable: "1" } },
          headers: {
            "Authorization" => "Bearer #{access_token}",
            "Client-Agent" => "Mozilla/5.0",
            "Host" => host,
            "X-TEST-SESSION-PUBLIC-ID" => token.public_id,
          }

    assert_response :unprocessable_content
    assert_not email.reload.notifiable?
  end
end
