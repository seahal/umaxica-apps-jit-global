# typed: false
# frozen_string_literal: true

require "test_helper"

# adr/unified-enforcement.md, Identifier attachment enforcement. Confirms the
# EnforcementIdentifierGate wiring added to the six identity-registration
# controllers (email/telephone x app/com/org) actually rejects an attachment
# blocked by an in-force Identifier Effect, through the real request/routing/
# authentication/step-up stack -- not just the concern's own unit tests.
class EnforcementIdentifierAttachmentGateTest < ActionDispatch::IntegrationTest
  fixtures :clients, :operators, :visitors

  setup do
    TurnstileVerifierStub.challenge_enabled = true
    TurnstileVerifierStub.challenge_response = { "success" => true }
  end

  teardown do
    TurnstileVerifierStub.challenge_enabled = false
    TurnstileVerifierStub.challenge_response = nil
  end

  test "app email attachment is rejected when blocked by an in-force attachment_blocked Identifier Effect" do
    host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    host! host
    user = clients(:one)
    headers =
      begin
        fx0_user = user
        fx0_host = host
        fx0_scope = "settings_email"
        fx0_token = ClientToken.create!(
          user: fx0_user,
          user_token_kind_id: ClientTokenKind::BROWSER_WEB,
          user_token_status_id: ClientTokenStatus::ACTIVE,
          discard_at: 1.day.from_now,
        )
        BaseSelectorBootstrapAuthority.call(surface: :app, principal: fx0_user)
        BaseSelectorAuthority.prepare(surface: :app, principal: fx0_user, session: fx0_token)
        _, fx0_raw_verification = ClientVerification.issue_for_token!(token: fx0_token)
        cookies[ClientVerification.cookie_name] = fx0_raw_verification
        fx0_token.update!(
          last_step_up_at: Time.current,
          last_step_up_scope: fx0_scope,
          last_step_up_aal: "aal2",
          last_step_up_method: "passkey",
          last_step_up_phishing_resistant: true, last_step_up_user_verified: true,
          last_step_up_credential_ref: "test-step-up-credential", last_step_up_full_reauthentication: false,
          last_step_up_session_public_id: fx0_token.public_id,
          last_step_up_purpose: "step_up",
          last_step_up_audience: "step_up:app",
        )
        fx0_access_token = AuthenticationToken.encode(
          fx0_user, host: fx0_host, session_public_id: fx0_token.public_id,
                    resource_type: "client", jwt_issuer_id: "surface:BASE_APP",
        )
        cookies[AuthenticationBase::ACCESS_COOKIE_KEY] = fx0_access_token
        # Base pages authenticate by the Browser RP credential; the root cookie alone does not.
        begin
          f0_cookie_pairs =
            begin
              f0_host = fx0_host
              f0_token = fx0_token
              f0_client = OidcClientRegistry.find!("base-app-ww")
              f0_key = [f0_client.client_id, f0_token.public_id]
              @base_browser_rp_credentials ||= {}
              if @base_browser_rp_credentials[f0_key] ||
                  (f0_token.currently_usable? &&
                    !(f0_token.device_session_id && OpAppGrant.exists?(
                      device_session_id: f0_token.device_session_id,
                      oidc_client_id: f0_client.client_id,
                      revoked_at: nil,
                    )))
                unless @base_browser_rp_credentials[f0_key]
                  f0_token.rotate_refresh_token! unless f0_token.device_session_record.current_refresh_token_id
                  f0_now = Time.current
                  f0_session = OpAppGrant.create!(
                    client_token: f0_token, oidc_client_id: f0_client.client_id, oidc_scope: "openid profile",
                    oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16), oidc_auth_time: f0_now,
                    refresh_token_expires_at: f0_now + 10.minutes,
                  )
                  f0_access = AuthenticationTokenService.encode(
                    fx0_user, host: f0_host, resource_type: "client",
                              session_public_id: f0_token.public_id, base_session_public_id: f0_token.public_id,
                              oidc_sid: f0_session.public_id, oidc_jti: f0_session.oidc_jti,
                              expires_at: f0_now + 10.minutes, scopes: %w(openid profile),
                              issuer: OidcIssuer.for_client(f0_client), audiences: [f0_client.aud],
                              jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(f0_client),
                              subject: OidcSubject.for(
                                fx0_user,
                                resource_type: "client",
                              ), client_id: f0_client.client_id,
                  )
                  @base_browser_rp_credentials[f0_key] =
                    [f0_access, f0_session.issue_refresh_token!]
                end
                f0_access, f0_refresh = @base_browser_rp_credentials.fetch(f0_key)
                [
                  "#{OidcRpBrowserCredentialContract::ACCESS_COOKIE}=#{Rack::Utils.escape(f0_access)}",
                  "#{OidcRpBrowserCredentialContract::REFRESH_COOKIE}=#{Rack::Utils.escape(f0_refresh)}",
                ]
              else
                []
              end
            end
          cookies.merge(f0_cookie_pairs, URI.parse("https://#{f0_host}/"))
        end
        {
          "Authorization" => "Bearer #{fx0_access_token}",
          "Client-Agent" => "Mozilla/5.0",
          "Host" => fx0_host,
          "X-TEST-SESSION-PUBLIC-ID" => fx0_token.public_id,
        }
      end

    operator = operators(:one)
    the_case = AppEnforcementCase.new(
      kind: "cooldown", duration_mode: "timed", visibility: "visible", release_mode: "automatic",
      effective_at: Time.current, expires_at: 1.day.from_now, reason_code: "abuse",
      principal_public_id: "some_other_client_public_id", applied_by_operator_public_id: operator.public_id,
    )
    digest = EnforcementIdentifierDigest.for_email(realm: "app", value: "app_attach_blocked@example.com")
    the_case.identifier_effects.build(**digest, attachment_blocked: true, effective_at: Time.current)
    EnforcementCaseApplyOperation.call(
      enforcement_case: the_case,
      actor_operator_public_id: the_case.applied_by_operator_public_id,
    )

    assert_no_difference("ClientEmail.count") do
      post base_app_identity_emails_registration_url(ri: "jp", host: host),
           params: { user_email: { address: "App_Attach_Blocked@Example.com" } },
           headers: headers
    end

    assert_response :unprocessable_content
  end

  test "app telephone attachment is rejected when blocked by an in-force attachment_blocked Identifier Effect" do
    host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    host! host
    user = clients(:one)
    headers =
      begin
        fx1_user = user
        fx1_host = host
        fx1_scope = "settings_telephone"
        fx1_token = ClientToken.create!(
          user: fx1_user,
          user_token_kind_id: ClientTokenKind::BROWSER_WEB,
          user_token_status_id: ClientTokenStatus::ACTIVE,
          discard_at: 1.day.from_now,
        )
        BaseSelectorBootstrapAuthority.call(surface: :app, principal: fx1_user)
        BaseSelectorAuthority.prepare(surface: :app, principal: fx1_user, session: fx1_token)
        _, fx1_raw_verification = ClientVerification.issue_for_token!(token: fx1_token)
        cookies[ClientVerification.cookie_name] = fx1_raw_verification
        fx1_token.update!(
          last_step_up_at: Time.current,
          last_step_up_scope: fx1_scope,
          last_step_up_aal: "aal2",
          last_step_up_method: "passkey",
          last_step_up_phishing_resistant: true, last_step_up_user_verified: true,
          last_step_up_credential_ref: "test-step-up-credential", last_step_up_full_reauthentication: false,
          last_step_up_session_public_id: fx1_token.public_id,
          last_step_up_purpose: "step_up",
          last_step_up_audience: "step_up:app",
        )
        fx1_access_token = AuthenticationToken.encode(
          fx1_user, host: fx1_host, session_public_id: fx1_token.public_id,
                    resource_type: "client", jwt_issuer_id: "surface:BASE_APP",
        )
        cookies[AuthenticationBase::ACCESS_COOKIE_KEY] = fx1_access_token
        # Base pages authenticate by the Browser RP credential; the root cookie alone does not.
        begin
          f1_cookie_pairs =
            begin
              f1_host = fx1_host
              f1_token = fx1_token
              f1_client = OidcClientRegistry.find!("base-app-ww")
              f1_key = [f1_client.client_id, f1_token.public_id]
              @base_browser_rp_credentials ||= {}
              if @base_browser_rp_credentials[f1_key] ||
                  (f1_token.currently_usable? &&
                    !(f1_token.device_session_id && OpAppGrant.exists?(
                      device_session_id: f1_token.device_session_id,
                      oidc_client_id: f1_client.client_id,
                      revoked_at: nil,
                    )))
                unless @base_browser_rp_credentials[f1_key]
                  f1_token.rotate_refresh_token! unless f1_token.device_session_record.current_refresh_token_id
                  f1_now = Time.current
                  f1_session = OpAppGrant.create!(
                    client_token: f1_token, oidc_client_id: f1_client.client_id, oidc_scope: "openid profile",
                    oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16), oidc_auth_time: f1_now,
                    refresh_token_expires_at: f1_now + 10.minutes,
                  )
                  f1_access = AuthenticationTokenService.encode(
                    fx1_user, host: f1_host, resource_type: "client",
                              session_public_id: f1_token.public_id, base_session_public_id: f1_token.public_id,
                              oidc_sid: f1_session.public_id, oidc_jti: f1_session.oidc_jti,
                              expires_at: f1_now + 10.minutes, scopes: %w(openid profile),
                              issuer: OidcIssuer.for_client(f1_client), audiences: [f1_client.aud],
                              jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(f1_client),
                              subject: OidcSubject.for(
                                fx1_user,
                                resource_type: "client",
                              ), client_id: f1_client.client_id,
                  )
                  @base_browser_rp_credentials[f1_key] =
                    [f1_access, f1_session.issue_refresh_token!]
                end
                f1_access, f1_refresh = @base_browser_rp_credentials.fetch(f1_key)
                [
                  "#{OidcRpBrowserCredentialContract::ACCESS_COOKIE}=#{Rack::Utils.escape(f1_access)}",
                  "#{OidcRpBrowserCredentialContract::REFRESH_COOKIE}=#{Rack::Utils.escape(f1_refresh)}",
                ]
              else
                []
              end
            end
          cookies.merge(f1_cookie_pairs, URI.parse("https://#{f1_host}/"))
        end
        {
          "Authorization" => "Bearer #{fx1_access_token}",
          "Client-Agent" => "Mozilla/5.0",
          "Host" => fx1_host,
          "X-TEST-SESSION-PUBLIC-ID" => fx1_token.public_id,
        }
      end

    operator = operators(:one)
    the_case = AppEnforcementCase.new(
      kind: "cooldown", duration_mode: "timed", visibility: "visible", release_mode: "automatic",
      effective_at: Time.current, expires_at: 1.day.from_now, reason_code: "abuse",
      principal_public_id: "some_other_client_public_id", applied_by_operator_public_id: operator.public_id,
    )
    digest = EnforcementIdentifierDigest.for_telephone(realm: "app", value: "+15558675301")
    the_case.identifier_effects.build(**digest, attachment_blocked: true, effective_at: Time.current)
    EnforcementCaseApplyOperation.call(
      enforcement_case: the_case,
      actor_operator_public_id: the_case.applied_by_operator_public_id,
    )

    assert_no_difference("ClientTelephone.count") do
      post base_app_identity_telephones_registration_url(ri: "jp", host: host),
           params: { user_telephone: { raw_number: "+15558675301" } },
           headers: headers
    end

    assert_response :unprocessable_content
  end

  test "com email attachment is rejected when blocked by an in-force attachment_blocked Identifier Effect" do
    host = ENV.fetch("PUBLIC_BASE_CORPORATE_URL")
    host! host
    visitor = visitors(:reserved_visitor)
    headers =
      begin
        fx2_visitor = visitor
        fx2_host = host
        fx2_token = VisitorToken.create!(
          visitor: fx2_visitor,
          visitor_token_kind_id: VisitorTokenKind::BROWSER_WEB,
          visitor_token_status_id: VisitorTokenStatus::ACTIVE,
          discard_at: 1.day.from_now,
        )
        BaseSelectorBootstrapAuthority.call(surface: :com, principal: fx2_visitor)
        BaseSelectorAuthority.prepare(surface: :com, principal: fx2_visitor, session: fx2_token)
        _, fx2_raw_verification = VisitorVerification.issue_for_token!(token: fx2_token)
        cookies[VisitorVerification.cookie_name] = fx2_raw_verification
        # Synthetic evidence isolates contact mutation; the public Base operation owns freshness.
        passkey = fx2_visitor.visitor_passkeys.create!(
          webauthn_id: SecureRandom.uuid, public_key: "app-contact-verification-public-key", sign_count: 0,
        )
        requirement = StepUpRequirement.new(
          scope: "settings_email", allowed_methods: [:passkey], purpose: "step_up", audience: "step_up:com",
          step_up_required: true, phishing_resistant_required: false, user_verification_required: false,
          full_reauthentication_required: false, ttl: 15.minutes, actor_ref: fx2_visitor.public_id,
          resource_ref: nil, tenant_ref: nil,
          session_binding: fx2_token.public_id, token_binding: fx2_token.public_id, require_session_binding: true,
        )
        issuance = BaseStepUpAdmissionIssuer.call!(
          actor: fx2_visitor,
          token: fx2_token,
          requirement: requirement,
          return_to: "/identity/emails/registration/new",
          base_browser_nonce: "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn",
          base_token: fx2_token,
        )
        transaction = issuance.transaction
        binding = BaseAuthAdmissionCoordinator.find_admission_binding!(surface: "com", reference: issuance.reference)
        attached, raw_sid = VisitorAuthCeremonySession.issue!
        binding.attach_auth_session!(auth_session: attached, confirmation_ref: SecureRandom.uuid)
        binding.confirm_base!(base_token: fx2_token, browser_digest: binding.base_browser_digest)
        BaseAuthAdmissionCoordinator.consume_entry_reference!(
          reference: issuance.reference, surface: "com", expected_intent: "step_up", binding: binding,
          raw_auth_sid: raw_sid,
        )
        transaction.record_verification!(
          method: "passkey", aal: "aal1", phishing_resistant: true,
          user_verified: true,
          verified_at: VisitorStepUpCeremonyTransaction.database_now, verified_credential_ref: passkey.public_id,
        )
        ceremony, = VisitorAuthCeremonySession.rotate_and_admit!(
          admission_purpose: "step_up_handoff", step_up_ceremony_transaction_ref: transaction.transaction_id,
          previous_raw_sid: raw_sid,
        )
        binding.redeem!(auth_session: attached, admitted_auth_session: ceremony)
        result = BaseAuthAdmissionCoordinator.issue_result!(
          transaction: transaction, ceremony_session_ref: ceremony.id.to_s,
        )
        IdentityStepUpCeremonyFreshnessCommitter.call!(
          actor: fx2_visitor,
          token: fx2_token,
          transaction: transaction,
          requirement: requirement,
          raw_result: result.code,
        )
        fx2_access_token = AuthenticationToken.encode(
          fx2_visitor, host: fx2_host, session_public_id: fx2_token.public_id,
                       resource_type: "visitor", jwt_issuer_id: "surface:BASE_COM",
        )
        cookies[AuthenticationBase::ACCESS_COOKIE_KEY] = fx2_access_token
        # Base pages authenticate by the Browser RP credential; the root cookie alone does not.
        begin
          f2_cookie_pairs =
            begin
              f2_host = fx2_host
              f2_token = fx2_token
              f2_client = OidcClientRegistry.find!("base-com-ww")
              f2_key = [f2_client.client_id, f2_token.public_id]
              @base_browser_rp_credentials ||= {}
              if @base_browser_rp_credentials[f2_key] ||
                  (f2_token.currently_usable? &&
                    !(f2_token.device_session_id && OpComGrant.exists?(
                      device_session_id: f2_token.device_session_id,
                      oidc_client_id: f2_client.client_id,
                      revoked_at: nil,
                    )))
                unless @base_browser_rp_credentials[f2_key]
                  f2_token.rotate_refresh_token! unless f2_token.device_session_record.current_refresh_token_id
                  f2_now = Time.current
                  f2_session = OpComGrant.create!(
                    visitor_token: f2_token, oidc_client_id: f2_client.client_id, oidc_scope: "openid profile",
                    oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16), oidc_auth_time: f2_now,
                    refresh_token_expires_at: f2_now + 10.minutes,
                  )
                  f2_access = AuthenticationTokenService.encode(
                    fx2_visitor,
                    host: f2_host,
                    resource_type: "visitor",
                    session_public_id: f2_token.public_id,
                    base_session_public_id: f2_token.public_id,
                    oidc_sid: f2_session.public_id,
                    oidc_jti: f2_session.oidc_jti,
                    expires_at: f2_now + 10.minutes,
                    scopes: %w(openid profile),
                    issuer: OidcIssuer.for_client(f2_client),
                    audiences: [f2_client.aud],
                    jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(f2_client),
                    subject: OidcSubject.for(
                      fx2_visitor,
                      resource_type: "visitor",
                    ),
                    client_id: f2_client.client_id,
                  )
                  @base_browser_rp_credentials[f2_key] =
                    [f2_access, f2_session.issue_refresh_token!]
                end
                f2_access, f2_refresh = @base_browser_rp_credentials.fetch(f2_key)
                [
                  "#{OidcRpBrowserCredentialContract::ACCESS_COOKIE}=#{Rack::Utils.escape(f2_access)}",
                  "#{OidcRpBrowserCredentialContract::REFRESH_COOKIE}=#{Rack::Utils.escape(f2_refresh)}",
                ]
              else
                []
              end
            end
          cookies.merge(f2_cookie_pairs, URI.parse("https://#{f2_host}/"))
        end
        {
          "Authorization" => "Bearer #{fx2_access_token}",
          "Client-Agent" => "Mozilla/5.0",
          "Host" => fx2_host,
          "X-TEST-SESSION-PUBLIC-ID" => fx2_token.public_id,
        }
      end

    operator = operators(:one)
    the_case = ComEnforcementCase.new(
      kind: "cooldown", duration_mode: "timed", visibility: "visible", release_mode: "automatic",
      effective_at: Time.current, expires_at: 1.day.from_now, reason_code: "abuse",
      principal_public_id: "some_other_visitor_public_id", applied_by_operator_public_id: operator.public_id,
    )
    digest = EnforcementIdentifierDigest.for_email(realm: "com", value: "com_attach_blocked@example.com")
    the_case.identifier_effects.build(**digest, attachment_blocked: true, effective_at: Time.current)
    EnforcementCaseApplyOperation.call(
      enforcement_case: the_case,
      actor_operator_public_id: the_case.applied_by_operator_public_id,
    )

    assert_no_difference("VisitorEmail.count") do
      post base_com_identity_emails_registration_url(ri: "jp", host: host),
           params: { visitor_email: { address: "Com_Attach_Blocked@Example.com" } },
           headers: headers
    end

    assert_response :unprocessable_content
  end

  test "com telephone attachment is rejected when blocked by an in-force attachment_blocked Identifier Effect" do
    host = ENV.fetch("PUBLIC_BASE_CORPORATE_URL")
    host! host
    visitor = visitors(:reserved_visitor)
    headers =
      begin
        fx3_visitor = visitor
        fx3_host = host
        fx3_scope = "settings_telephone"
        fx3_token = VisitorToken.create!(
          visitor: fx3_visitor,
          visitor_token_kind_id: VisitorTokenKind::BROWSER_WEB,
          visitor_token_status_id: VisitorTokenStatus::ACTIVE,
          discard_at: 1.day.from_now,
        )
        BaseSelectorBootstrapAuthority.call(surface: :com, principal: fx3_visitor)
        BaseSelectorAuthority.prepare(surface: :com, principal: fx3_visitor, session: fx3_token)
        _, fx3_raw_verification = VisitorVerification.issue_for_token!(token: fx3_token)
        cookies[VisitorVerification.cookie_name] = fx3_raw_verification
        fx3_token.update!(
          last_step_up_at: Time.current,
          last_step_up_scope: fx3_scope,
          last_step_up_aal: "aal2",
          last_step_up_method: "passkey",
          last_step_up_phishing_resistant: true, last_step_up_user_verified: true,
          last_step_up_credential_ref: "test-step-up-credential", last_step_up_full_reauthentication: false,
          last_step_up_session_public_id: fx3_token.public_id,
          last_step_up_purpose: "step_up",
          last_step_up_audience: "step_up:com",
        )
        fx3_access_token = AuthenticationToken.encode(
          fx3_visitor, host: fx3_host, session_public_id: fx3_token.public_id,
                       resource_type: "visitor", jwt_issuer_id: "surface:BASE_COM",
        )
        cookies[AuthenticationBase::ACCESS_COOKIE_KEY] = fx3_access_token
        # Base pages authenticate by the Browser RP credential; the root cookie alone does not.
        begin
          f3_cookie_pairs =
            begin
              f3_host = fx3_host
              f3_token = fx3_token
              f3_client = OidcClientRegistry.find!("base-com-ww")
              f3_key = [f3_client.client_id, f3_token.public_id]
              @base_browser_rp_credentials ||= {}
              if @base_browser_rp_credentials[f3_key] ||
                  (f3_token.currently_usable? &&
                    !(f3_token.device_session_id && OpComGrant.exists?(
                      device_session_id: f3_token.device_session_id,
                      oidc_client_id: f3_client.client_id,
                      revoked_at: nil,
                    )))
                unless @base_browser_rp_credentials[f3_key]
                  f3_token.rotate_refresh_token! unless f3_token.device_session_record.current_refresh_token_id
                  f3_now = Time.current
                  f3_session = OpComGrant.create!(
                    visitor_token: f3_token, oidc_client_id: f3_client.client_id, oidc_scope: "openid profile",
                    oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16), oidc_auth_time: f3_now,
                    refresh_token_expires_at: f3_now + 10.minutes,
                  )
                  f3_access = AuthenticationTokenService.encode(
                    fx3_visitor,
                    host: f3_host,
                    resource_type: "visitor",
                    session_public_id: f3_token.public_id,
                    base_session_public_id: f3_token.public_id,
                    oidc_sid: f3_session.public_id,
                    oidc_jti: f3_session.oidc_jti,
                    expires_at: f3_now + 10.minutes,
                    scopes: %w(openid profile),
                    issuer: OidcIssuer.for_client(f3_client),
                    audiences: [f3_client.aud],
                    jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(f3_client),
                    subject: OidcSubject.for(
                      fx3_visitor,
                      resource_type: "visitor",
                    ),
                    client_id: f3_client.client_id,
                  )
                  @base_browser_rp_credentials[f3_key] =
                    [f3_access, f3_session.issue_refresh_token!]
                end
                f3_access, f3_refresh = @base_browser_rp_credentials.fetch(f3_key)
                [
                  "#{OidcRpBrowserCredentialContract::ACCESS_COOKIE}=#{Rack::Utils.escape(f3_access)}",
                  "#{OidcRpBrowserCredentialContract::REFRESH_COOKIE}=#{Rack::Utils.escape(f3_refresh)}",
                ]
              else
                []
              end
            end
          cookies.merge(f3_cookie_pairs, URI.parse("https://#{f3_host}/"))
        end
        {
          "Authorization" => "Bearer #{fx3_access_token}",
          "Client-Agent" => "Mozilla/5.0",
          "Host" => fx3_host,
          "X-TEST-SESSION-PUBLIC-ID" => fx3_token.public_id,
        }
      end

    operator = operators(:one)
    the_case = ComEnforcementCase.new(
      kind: "cooldown", duration_mode: "timed", visibility: "visible", release_mode: "automatic",
      effective_at: Time.current, expires_at: 1.day.from_now, reason_code: "abuse",
      principal_public_id: "some_other_visitor_public_id", applied_by_operator_public_id: operator.public_id,
    )
    digest = EnforcementIdentifierDigest.for_telephone(realm: "com", value: "+15558675302")
    the_case.identifier_effects.build(**digest, attachment_blocked: true, effective_at: Time.current)
    EnforcementCaseApplyOperation.call(
      enforcement_case: the_case,
      actor_operator_public_id: the_case.applied_by_operator_public_id,
    )

    assert_no_difference("VisitorTelephone.count") do
      post base_com_identity_telephones_registration_url(ri: "jp", host: host),
           params: { user_telephone: { raw_number: "+15558675302" } },
           headers: headers
    end

    assert_response :unprocessable_content
  end

  test "org email attachment is rejected when blocked by an in-force attachment_blocked Identifier Effect" do
    host = ENV.fetch("PUBLIC_BASE_STAFF_URL")
    host! host
    operator = operators(:one)
    headers =
      begin
        fx4_operator = operator
        fx4_host = host
        fx4_scope = "settings_email"
        fx4_token = OperatorToken.create!(
          staff: fx4_operator,
          staff_token_kind_id: OperatorTokenKind::BROWSER_WEB,
          staff_token_status_id: OperatorTokenStatus::ACTIVE,
          discard_at: 1.day.from_now,
        )
        BaseSelectorBootstrapAuthority.call(surface: :org, principal: fx4_operator)
        BaseSelectorAuthority.prepare(surface: :org, principal: fx4_operator, session: fx4_token)
        _, fx4_raw_verification = OperatorVerification.issue_for_token!(token: fx4_token)
        cookies[OperatorVerification.cookie_name] = fx4_raw_verification
        fx4_token.update!(
          last_step_up_at: Time.current,
          last_step_up_scope: fx4_scope,
          last_step_up_aal: "aal2",
          last_step_up_method: "passkey",
          last_step_up_phishing_resistant: true, last_step_up_user_verified: true,
          last_step_up_credential_ref: "test-step-up-credential", last_step_up_full_reauthentication: false,
          last_step_up_session_public_id: fx4_token.public_id,
          last_step_up_purpose: "step_up",
          last_step_up_audience: "step_up:org",
        )
        fx4_access_token = AuthenticationToken.encode(
          fx4_operator, host: fx4_host, session_public_id: fx4_token.public_id,
                        resource_type: "operator", jwt_issuer_id: "surface:BASE_ORG",
        )
        cookies[AuthenticationBase::ACCESS_COOKIE_KEY] = fx4_access_token
        # Base pages authenticate by the Browser RP credential; the root cookie alone does not.
        begin
          f4_cookie_pairs =
            begin
              f4_host = fx4_host
              f4_token = fx4_token
              f4_client = OidcClientRegistry.find!("base-org-ww")
              f4_key = [f4_client.client_id, f4_token.public_id]
              @base_browser_rp_credentials ||= {}
              if @base_browser_rp_credentials[f4_key] ||
                  (f4_token.currently_usable? &&
                    !(f4_token.device_session_id && OpOrgGrant.exists?(
                      device_session_id: f4_token.device_session_id,
                      oidc_client_id: f4_client.client_id,
                      revoked_at: nil,
                    )))
                unless @base_browser_rp_credentials[f4_key]
                  f4_token.rotate_refresh_token! unless f4_token.device_session_record.current_refresh_token_id
                  f4_now = Time.current
                  f4_session = OpOrgGrant.create!(
                    operator_token: f4_token, oidc_client_id: f4_client.client_id, oidc_scope: "openid profile",
                    oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16), oidc_auth_time: f4_now,
                    refresh_token_expires_at: f4_now + 10.minutes,
                  )
                  f4_access = AuthenticationTokenService.encode(
                    fx4_operator,
                    host: f4_host,
                    resource_type: "operator",
                    session_public_id: f4_token.public_id,
                    base_session_public_id: f4_token.public_id,
                    oidc_sid: f4_session.public_id,
                    oidc_jti: f4_session.oidc_jti,
                    expires_at: f4_now + 10.minutes,
                    scopes: %w(openid profile),
                    issuer: OidcIssuer.for_client(f4_client),
                    audiences: [f4_client.aud],
                    jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(f4_client),
                    subject: OidcSubject.for(
                      fx4_operator,
                      resource_type: "operator",
                    ),
                    client_id: f4_client.client_id,
                  )
                  @base_browser_rp_credentials[f4_key] =
                    [f4_access, f4_session.issue_refresh_token!]
                end
                f4_access, f4_refresh = @base_browser_rp_credentials.fetch(f4_key)
                [
                  "#{OidcRpBrowserCredentialContract::ACCESS_COOKIE}=#{Rack::Utils.escape(f4_access)}",
                  "#{OidcRpBrowserCredentialContract::REFRESH_COOKIE}=#{Rack::Utils.escape(f4_refresh)}",
                ]
              else
                []
              end
            end
          cookies.merge(f4_cookie_pairs, URI.parse("https://#{f4_host}/"))
        end
        {
          "Authorization" => "Bearer #{fx4_access_token}",
          "Client-Agent" => "Mozilla/5.0",
          "Host" => fx4_host,
          "X-TEST-SESSION-PUBLIC-ID" => fx4_token.public_id,
        }
      end

    blocking_operator = operators(:one)
    the_case = OrgEnforcementCase.new(
      kind: "cooldown", duration_mode: "timed", visibility: "visible", release_mode: "automatic",
      effective_at: Time.current, expires_at: 1.day.from_now, reason_code: "abuse",
      principal_public_id: "some_other_operator_public_id",
      applied_by_operator_public_id: blocking_operator.public_id,
    )
    digest = EnforcementIdentifierDigest.for_email(realm: "org", value: "org_attach_blocked@example.com")
    the_case.identifier_effects.build(**digest, attachment_blocked: true, effective_at: Time.current)
    EnforcementCaseApplyOperation.call(
      enforcement_case: the_case,
      actor_operator_public_id: the_case.applied_by_operator_public_id,
    )

    assert_no_difference("OperatorEmail.count") do
      post base_org_identity_emails_registration_url(ri: "jp", host: host),
           params: { staff_email: { address: "Org_Attach_Blocked@Example.com" } },
           headers: headers
    end

    assert_response :unprocessable_content
  end

  test "org telephone attachment is rejected when blocked by an in-force attachment_blocked Identifier Effect" do
    host = ENV.fetch("PUBLIC_BASE_STAFF_URL")
    host! host
    operator = operators(:one)
    headers =
      begin
        fx5_operator = operator
        fx5_host = host
        fx5_scope = "settings_telephone"
        fx5_token = OperatorToken.create!(
          staff: fx5_operator,
          staff_token_kind_id: OperatorTokenKind::BROWSER_WEB,
          staff_token_status_id: OperatorTokenStatus::ACTIVE,
          discard_at: 1.day.from_now,
        )
        BaseSelectorBootstrapAuthority.call(surface: :org, principal: fx5_operator)
        BaseSelectorAuthority.prepare(surface: :org, principal: fx5_operator, session: fx5_token)
        _, fx5_raw_verification = OperatorVerification.issue_for_token!(token: fx5_token)
        cookies[OperatorVerification.cookie_name] = fx5_raw_verification
        fx5_token.update!(
          last_step_up_at: Time.current,
          last_step_up_scope: fx5_scope,
          last_step_up_aal: "aal2",
          last_step_up_method: "passkey",
          last_step_up_phishing_resistant: true, last_step_up_user_verified: true,
          last_step_up_credential_ref: "test-step-up-credential", last_step_up_full_reauthentication: false,
          last_step_up_session_public_id: fx5_token.public_id,
          last_step_up_purpose: "step_up",
          last_step_up_audience: "step_up:org",
        )
        fx5_access_token = AuthenticationToken.encode(
          fx5_operator, host: fx5_host, session_public_id: fx5_token.public_id,
                        resource_type: "operator", jwt_issuer_id: "surface:BASE_ORG",
        )
        cookies[AuthenticationBase::ACCESS_COOKIE_KEY] = fx5_access_token
        # Base pages authenticate by the Browser RP credential; the root cookie alone does not.
        begin
          f5_cookie_pairs =
            begin
              f5_host = fx5_host
              f5_token = fx5_token
              f5_client = OidcClientRegistry.find!("base-org-ww")
              f5_key = [f5_client.client_id, f5_token.public_id]
              @base_browser_rp_credentials ||= {}
              if @base_browser_rp_credentials[f5_key] ||
                  (f5_token.currently_usable? &&
                    !(f5_token.device_session_id && OpOrgGrant.exists?(
                      device_session_id: f5_token.device_session_id,
                      oidc_client_id: f5_client.client_id,
                      revoked_at: nil,
                    )))
                unless @base_browser_rp_credentials[f5_key]
                  f5_token.rotate_refresh_token! unless f5_token.device_session_record.current_refresh_token_id
                  f5_now = Time.current
                  f5_session = OpOrgGrant.create!(
                    operator_token: f5_token, oidc_client_id: f5_client.client_id, oidc_scope: "openid profile",
                    oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16), oidc_auth_time: f5_now,
                    refresh_token_expires_at: f5_now + 10.minutes,
                  )
                  f5_access = AuthenticationTokenService.encode(
                    fx5_operator,
                    host: f5_host,
                    resource_type: "operator",
                    session_public_id: f5_token.public_id,
                    base_session_public_id: f5_token.public_id,
                    oidc_sid: f5_session.public_id,
                    oidc_jti: f5_session.oidc_jti,
                    expires_at: f5_now + 10.minutes,
                    scopes: %w(openid profile),
                    issuer: OidcIssuer.for_client(f5_client),
                    audiences: [f5_client.aud],
                    jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(f5_client),
                    subject: OidcSubject.for(
                      fx5_operator,
                      resource_type: "operator",
                    ),
                    client_id: f5_client.client_id,
                  )
                  @base_browser_rp_credentials[f5_key] =
                    [f5_access, f5_session.issue_refresh_token!]
                end
                f5_access, f5_refresh = @base_browser_rp_credentials.fetch(f5_key)
                [
                  "#{OidcRpBrowserCredentialContract::ACCESS_COOKIE}=#{Rack::Utils.escape(f5_access)}",
                  "#{OidcRpBrowserCredentialContract::REFRESH_COOKIE}=#{Rack::Utils.escape(f5_refresh)}",
                ]
              else
                []
              end
            end
          cookies.merge(f5_cookie_pairs, URI.parse("https://#{f5_host}/"))
        end
        {
          "Authorization" => "Bearer #{fx5_access_token}",
          "Client-Agent" => "Mozilla/5.0",
          "Host" => fx5_host,
          "X-TEST-SESSION-PUBLIC-ID" => fx5_token.public_id,
        }
      end

    blocking_operator = operators(:one)
    the_case = OrgEnforcementCase.new(
      kind: "cooldown", duration_mode: "timed", visibility: "visible", release_mode: "automatic",
      effective_at: Time.current, expires_at: 1.day.from_now, reason_code: "abuse",
      principal_public_id: "some_other_operator_public_id",
      applied_by_operator_public_id: blocking_operator.public_id,
    )
    digest = EnforcementIdentifierDigest.for_telephone(realm: "org", value: "+15558675303")
    the_case.identifier_effects.build(**digest, attachment_blocked: true, effective_at: Time.current)
    EnforcementCaseApplyOperation.call(
      enforcement_case: the_case,
      actor_operator_public_id: the_case.applied_by_operator_public_id,
    )

    assert_no_difference("OperatorTelephone.count") do
      post base_org_identity_telephones_registration_url(ri: "jp", host: host),
           params: { staff_telephone: { raw_number: "+15558675303" } },
           headers: headers
    end

    assert_response :unprocessable_content
  end

  private
end
