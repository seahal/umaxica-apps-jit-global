# typed: false
# frozen_string_literal: true

require "test_helper"

class DeliveredOtpAutocompleteTest < ActionDispatch::IntegrationTest
  fixtures :clients, :operators, :visitors

  setup do
    TurnstileVerifierStub.challenge_enabled = true
    TurnstileVerifierStub.challenge_response = { "success" => true }
  end

  teardown do
    TurnstileVerifierStub.challenge_enabled = false
    TurnstileVerifierStub.challenge_response = nil
  end

  test "app identity email and telephone otp inputs allow one time code autocomplete" do
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
    # Synthetic evidence isolates contact mutation; the public Base operation owns freshness.
    passkey = user.client_passkeys.create!(
      webauthn_id: SecureRandom.uuid, public_key: "app-contact-verification-public-key", sign_count: 0,
    )
    requirement = StepUpRequirement.new(
      scope: "settings_email", allowed_methods: [:passkey], purpose: "step_up", audience: "step_up:app",
      step_up_required: true, phishing_resistant_required: false, user_verification_required: false,
      full_reauthentication_required: false, ttl: 15.minutes, actor_ref: user.public_id,
      resource_ref: nil, tenant_ref: nil,
      session_binding: token.public_id, token_binding: token.public_id, require_session_binding: true,
    )
    issuance = BaseStepUpAdmissionIssuer.call!(
      actor: user,
      token: token,
      requirement: requirement,
      return_to: "/identity/emails/registration/new",
      base_browser_nonce: "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn",
      base_token: token,
    )
    transaction = issuance.transaction
    binding = BaseAuthAdmissionCoordinator.find_admission_binding!(surface: "app", reference: issuance.reference)
    attached, raw_sid = ClientAuthCeremonySession.issue!
    binding.attach_auth_session!(auth_session: attached, confirmation_ref: SecureRandom.uuid)
    binding.confirm_base!(base_token: token, browser_digest: binding.base_browser_digest)
    BaseAuthAdmissionCoordinator.consume_entry_reference!(
      reference: issuance.reference, surface: "app", expected_intent: "step_up", binding: binding,
      raw_auth_sid: raw_sid,
    )
    transaction.record_verification!(
      method: "passkey", aal: "aal1", phishing_resistant: true,
      user_verified: true,
      verified_at: ClientStepUpCeremonyTransaction.database_now, verified_credential_ref: passkey.public_id,
    )
    ceremony, = ClientAuthCeremonySession.rotate_and_admit!(
      admission_purpose: "step_up_handoff", step_up_ceremony_transaction_ref: transaction.transaction_id,
      previous_raw_sid: raw_sid,
    )
    binding.redeem!(auth_session: attached, admitted_auth_session: ceremony)
    result = BaseAuthAdmissionCoordinator.issue_result!(
      transaction: transaction, ceremony_session_ref: ceremony.id.to_s,
    )
    IdentityStepUpCeremonyFreshnessCommitter.call!(
      actor: user, token: token, transaction: transaction, requirement: requirement, raw_result: result.code,
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
      "Client-Agent" => "Mozilla/5.0",
      "Host" => host,
      "X-TEST-SESSION-PUBLIC-ID" => token.public_id,
    }

    get new_base_app_identity_emails_registration_url(ri: "jp", host: host), headers: headers

    assert_response :success

    fake_adapter = Object.new
    fake_adapter.define_singleton_method(:deliver) { |**_args| true }
    OtpAdapter.stub(:for, fake_adapter) do
      post base_app_identity_emails_registration_url(ri: "jp", host: host),
           params: { user_email: { address: "app-otp-autocomplete-#{SecureRandom.hex(4)}@example.test" } },
           headers: headers
    end

    assert_response :redirect
    follow_redirect!(headers: headers)

    assert_response :success
    # The one-time-code input, its `user_email[pass_code]` parameter and its autocomplete hint all live in
    # this component; the page object shows the visitor was sent to it with a code form to post.
    assert_equal "base/app/identity/emails/registrations/edit", inertia_component
    assert_predicate inertia_props.fetch("form").fetch("action"), :present?
    assert_predicate inertia_props.dig("form", "code_label") || inertia_props.fetch("code_label"), :present?

    # Synthetic evidence isolates contact mutation; the public Base operation owns freshness.
    passkey = user.client_passkeys.create!(
      webauthn_id: SecureRandom.uuid, public_key: "app-contact-verification-public-key", sign_count: 0,
    )
    requirement = StepUpRequirement.new(
      scope: "settings_telephone", allowed_methods: [:passkey], purpose: "step_up", audience: "step_up:app",
      step_up_required: true, phishing_resistant_required: false, user_verification_required: false,
      full_reauthentication_required: false, ttl: 15.minutes, actor_ref: user.public_id,
      resource_ref: nil, tenant_ref: nil,
      session_binding: token.public_id, token_binding: token.public_id, require_session_binding: true,
    )
    issuance = BaseStepUpAdmissionIssuer.call!(
      actor: user,
      token: token,
      requirement: requirement,
      return_to: "/identity/telephones/registration/new",
      base_browser_nonce: "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn",
      base_token: token,
    )
    transaction = issuance.transaction
    binding = BaseAuthAdmissionCoordinator.find_admission_binding!(surface: "app", reference: issuance.reference)
    attached, raw_sid = ClientAuthCeremonySession.issue!
    binding.attach_auth_session!(auth_session: attached, confirmation_ref: SecureRandom.uuid)
    binding.confirm_base!(base_token: token, browser_digest: binding.base_browser_digest)
    BaseAuthAdmissionCoordinator.consume_entry_reference!(
      reference: issuance.reference, surface: "app", expected_intent: "step_up", binding: binding,
      raw_auth_sid: raw_sid,
    )
    transaction.record_verification!(
      method: "passkey", aal: "aal1", phishing_resistant: true,
      user_verified: true,
      verified_at: ClientStepUpCeremonyTransaction.database_now, verified_credential_ref: passkey.public_id,
    )
    ceremony, = ClientAuthCeremonySession.rotate_and_admit!(
      admission_purpose: "step_up_handoff", step_up_ceremony_transaction_ref: transaction.transaction_id,
      previous_raw_sid: raw_sid,
    )
    binding.redeem!(auth_session: attached, admitted_auth_session: ceremony)
    result = BaseAuthAdmissionCoordinator.issue_result!(
      transaction: transaction, ceremony_session_ref: ceremony.id.to_s,
    )
    IdentityStepUpCeremonyFreshnessCommitter.call!(
      actor: user, token: token, transaction: transaction, requirement: requirement, raw_result: result.code,
    )

    OtpAdapter.stub(:for, fake_adapter) do
      post base_app_identity_telephones_registration_url(ri: "jp", host: host),
           params: { user_telephone: { raw_number: "+819012345601" } },
           headers: headers
    end

    assert_response :redirect
    follow_redirect!(headers: headers)

    assert_response :success
    # The one-time-code input, its `client_telephone[pass_code]` parameter and its autocomplete hint all live in
    # this component; the page object shows the visitor was sent to it with a code form to post.
    assert_equal "base/app/identity/telephones/registrations/edit", inertia_component
    assert_predicate inertia_props.fetch("form").fetch("action"), :present?
    assert_predicate inertia_props.dig("form", "code_label") || inertia_props.fetch("code_label"), :present?
  end

  test "com identity email and telephone otp inputs allow one time code autocomplete" do
    host = ENV.fetch("PUBLIC_BASE_CORPORATE_URL")
    host! host
    visitor = visitors(:reserved_visitor)
    token = VisitorToken.create!(
      authentication_epoch: 0,
      visitor: visitor,
      visitor_token_kind_id: VisitorTokenKind::BROWSER_WEB,
      visitor_token_status_id: VisitorTokenStatus::ACTIVE,
      discard_at: 1.day.from_now,
    )
    BaseSelectorBootstrapAuthority.call(surface: :com, principal: visitor)
    BaseSelectorAuthority.prepare(surface: :com, principal: visitor, session: token)
    _verification, raw_verification = VisitorVerification.issue_for_token!(token: token)
    cookies[VisitorVerification.cookie_name] = raw_verification
    # Synthetic evidence isolates contact mutation; the public Base operation owns freshness.
    passkey = visitor.visitor_passkeys.create!(
      webauthn_id: SecureRandom.uuid, public_key: "app-contact-verification-public-key", sign_count: 0,
    )
    requirement = StepUpRequirement.new(
      scope: "settings_email", allowed_methods: [:passkey], purpose: "step_up", audience: "step_up:com",
      step_up_required: true, phishing_resistant_required: false, user_verification_required: false,
      full_reauthentication_required: false, ttl: 15.minutes, actor_ref: visitor.public_id,
      resource_ref: nil, tenant_ref: nil,
      session_binding: token.public_id, token_binding: token.public_id, require_session_binding: true,
    )
    issuance = BaseStepUpAdmissionIssuer.call!(
      actor: visitor,
      token: token,
      requirement: requirement,
      return_to: "/identity/emails/registration/new",
      base_browser_nonce: "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn",
      base_token: token,
    )
    transaction = issuance.transaction
    binding = BaseAuthAdmissionCoordinator.find_admission_binding!(surface: "com", reference: issuance.reference)
    attached, raw_sid = VisitorAuthCeremonySession.issue!
    binding.attach_auth_session!(auth_session: attached, confirmation_ref: SecureRandom.uuid)
    binding.confirm_base!(base_token: token, browser_digest: binding.base_browser_digest)
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
      actor: visitor, token: token, transaction: transaction, requirement: requirement, raw_result: result.code,
    )
    access_token = AuthenticationToken.encode(
      visitor,
      host: host,
      session_public_id: token.public_id,
      resource_type: "visitor",
      jwt_issuer_id: "surface:BASE_COM",
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
                authentication_epoch: 0,
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
    headers = {
      "Authorization" => "Bearer #{access_token}",
      "Client-Agent" => "Mozilla/5.0",
      "Host" => host,
      "X-TEST-SESSION-PUBLIC-ID" => token.public_id,
    }

    get new_base_com_identity_emails_registration_url(ri: "jp", host: host), headers: headers

    assert_response :success

    fake_adapter = Object.new
    fake_adapter.define_singleton_method(:deliver) { |**_args| true }
    OtpAdapter.stub(:for, fake_adapter) do
      post base_com_identity_emails_registration_url(ri: "jp", host: host),
           params: { visitor_email: { address: "com-otp-autocomplete-#{SecureRandom.hex(4)}@example.test" } },
           headers: headers
    end

    assert_response :redirect
    follow_redirect!(headers: headers)

    assert_response :success
    # The one-time-code input, its `visitor_email[pass_code]` parameter and its autocomplete hint all live in
    # this component; the page object shows the visitor was sent to it with a code form to post.
    assert_equal "base/com/identity/emails/registrations/edit", inertia_component
    assert_predicate inertia_props.fetch("form").fetch("url"), :present?
    assert_predicate inertia_props.dig("form", "code_label") || inertia_props.fetch("code_label"), :present?

    # Synthetic evidence isolates contact mutation; the public Base operation owns freshness.
    passkey = visitor.visitor_passkeys.create!(
      webauthn_id: SecureRandom.uuid, public_key: "app-contact-verification-public-key", sign_count: 0,
    )
    requirement = StepUpRequirement.new(
      scope: "settings_telephone", allowed_methods: [:passkey], purpose: "step_up", audience: "step_up:com",
      step_up_required: true, phishing_resistant_required: false, user_verification_required: false,
      full_reauthentication_required: false, ttl: 15.minutes, actor_ref: visitor.public_id,
      resource_ref: nil, tenant_ref: nil,
      session_binding: token.public_id, token_binding: token.public_id, require_session_binding: true,
    )
    issuance = BaseStepUpAdmissionIssuer.call!(
      actor: visitor,
      token: token,
      requirement: requirement,
      return_to: "/identity/telephones/registration/new",
      base_browser_nonce: "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn",
      base_token: token,
    )
    transaction = issuance.transaction
    binding = BaseAuthAdmissionCoordinator.find_admission_binding!(surface: "com", reference: issuance.reference)
    attached, raw_sid = VisitorAuthCeremonySession.issue!
    binding.attach_auth_session!(auth_session: attached, confirmation_ref: SecureRandom.uuid)
    binding.confirm_base!(base_token: token, browser_digest: binding.base_browser_digest)
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
      actor: visitor, token: token, transaction: transaction, requirement: requirement, raw_result: result.code,
    )

    OtpAdapter.stub(:for, fake_adapter) do
      post base_com_identity_telephones_registration_url(ri: "jp", host: host),
           params: { visitor_telephone: { raw_number: "+819112345602" } },
           headers: headers
    end

    assert_response :redirect
    follow_redirect!(headers: headers)

    assert_response :success
    # The one-time-code input, its `visitor_telephone[pass_code]` parameter and its autocomplete hint all live in
    # this component; the page object shows the visitor was sent to it with a code form to post.
    assert_equal "base/com/identity/telephones/registrations/edit", inertia_component
    assert_predicate inertia_props.fetch("form").fetch("url"), :present?
    assert_predicate inertia_props.dig("form", "code_label") || inertia_props.fetch("code_label"), :present?
  end

  test "org identity email and telephone otp inputs allow one time code autocomplete" do
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
      last_step_up_scope: "settings_email",
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
      "Client-Agent" => "Mozilla/5.0",
      "Host" => host,
      "X-TEST-SESSION-PUBLIC-ID" => token.public_id,
    }

    get new_base_org_identity_emails_registration_url(ri: "jp", host: host), headers: headers

    assert_response :success

    fake_adapter = Object.new
    fake_adapter.define_singleton_method(:deliver) { |**_args| true }
    OtpAdapter.stub(:for, fake_adapter) do
      post base_org_identity_emails_registration_url(ri: "jp", host: host),
           params: { staff_email: { address: "org-otp-autocomplete-#{SecureRandom.hex(4)}@example.test" } },
           headers: headers
    end

    assert_response :redirect
    follow_redirect!(headers: headers)

    assert_response :success
    # The one-time-code input, its `staff_email[pass_code]` parameter and its autocomplete hint all live in
    # this component; the page object shows the visitor was sent to it with a code form to post.
    assert_equal "base/org/identity/emails/registrations/edit", inertia_component
    assert_predicate inertia_props.fetch("form").fetch("action"), :present?
    assert_predicate inertia_props.dig("form", "code_label") || inertia_props.fetch("code_label"), :present?

    token.update!(last_step_up_scope: "settings_telephone")
    OtpAdapter.stub(:for, fake_adapter) do
      post base_org_identity_telephones_registration_url(ri: "jp", host: host),
           params: { staff_telephone: { raw_number: "+819212345603" } },
           headers: headers
    end

    assert_response :redirect
    follow_redirect!(headers: headers)

    assert_response :success
    # The one-time-code input, its `operator_telephone[pass_code]` parameter and its autocomplete hint all live in
    # this component; the page object shows the visitor was sent to it with a code form to post.
    assert_equal "base/org/identity/telephones/registrations/edit", inertia_component
    assert_predicate inertia_props.fetch("form").fetch("action"), :present?
    assert_predicate inertia_props.dig("form", "code_label") || inertia_props.fetch("code_label"), :present?
  end
end
