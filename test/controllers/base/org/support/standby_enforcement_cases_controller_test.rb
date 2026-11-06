# typed: false
# frozen_string_literal: true

require "test_helper"

class Base::Org::Support::StandbyEnforcementCasesControllerTest < ActionDispatch::IntegrationTest
  self.fixture_table_names = []
  include ActiveJob::TestHelper

  setup do
    @host = ENV.fetch("PUBLIC_BASE_STAFF_URL")
    @operator = Operator.create!(
      security_mode_id: SecurityModeConfigurable::ADVANCED,
      status_id: OperatorStatus::ACTIVE,
      visibility_id: OperatorVisibility::STAFF,
    )
    2.times do
      OperatorPasskey.create!(
        staff_id: @operator.id,
        webauthn_id: SecureRandom.urlsafe_base64(32),
        external_id: SecureRandom.uuid,
        public_key: "standby-enforcement-test-public-key",
        sign_count: 0,
        description: "Standby enforcement test Passkey",
        status_id: OperatorPasskeyStatus::ACTIVE,
      )
    end
    @approver = Operator.create!(
      security_mode_id: SecurityModeConfigurable::ADVANCED,
      status_id: OperatorStatus::ACTIVE,
      visibility_id: OperatorVisibility::STAFF,
    )
    @principal = Client.create!(
      security_mode_id: SecurityModeConfigurable::NORMAL,
      status_id: ClientStatus::ACTIVE,
      visibility_id: ClientVisibility::USER,
    )
    BaseSelectorBootstrapAuthority.call(surface: :app, principal: @principal)
    BaseSelectorBootstrapAuthority.call(surface: :org, principal: @operator)
    @operator_token = OperatorToken.create!(
      authentication_epoch: 0,
      staff_id: @operator.id,
      staff_token_kind_id: OperatorTokenKind::BROWSER_WEB,
      staff_token_status_id: OperatorTokenStatus::ACTIVE,
      staff_token_binding_method_id: OperatorTokenBindingMethod::LEGACY,
      staff_token_dbsc_status_id: OperatorTokenDbscStatus::NOTHING,
      root_login_established_at: Time.current,
      established_authentication_method: "passkey",
      authentication_context: AuthenticationContextValue::STANDBY_KEY,
    )
    BaseSelectorAuthority.prepare(surface: :org, principal: @operator, session: @operator_token)
  end

  teardown do
    TurnstileVerifierStub.challenge_enabled = false
    TurnstileVerifierStub.challenge_response = nil
  end

  test "Standby cannot apply, approve, release or review enforcement cases despite fresh Step-Up" do
    [OperatorCapabilityGrant::ENFORCEMENT_READ_APP,
     OperatorCapabilityGrant::ENFORCEMENT_APPLY_APP,
     OperatorCapabilityGrant::ENFORCEMENT_APPROVE_APP,
     OperatorCapabilityGrant::ENFORCEMENT_RELEASE_APP,
     OperatorCapabilityGrant::ENFORCEMENT_REVIEW_APPEAL_APP,].each do |capability|
      OperatorCapabilityGrant.create!(
        operator: @operator,
        granted_by_operator: @approver,
        origin: "grant",
        capability: capability,
        reason_code: "duty_assignment",
        starts_at: 1.minute.ago,
        expires_at: 1.day.from_now,
      )
    end

    approval_case = AppEnforcementCase.create!(
      kind: "permanent_ban",
      duration_mode: "permanent",
      visibility: "hidden",
      release_mode: "break_glass_only",
      effective_at: Time.current,
      reason_code: "abuse",
      principal_public_id: @principal.public_id,
      applied_by_operator_public_id: @approver.public_id,
      state: "pending_approval",
    )
    release_case = AppEnforcementCase.new(
      kind: "temporary_freeze",
      duration_mode: "timed",
      visibility: "visible",
      release_mode: "operator",
      effective_at: Time.current,
      expires_at: 1.day.from_now,
      reason_code: "security_incident",
      principal_public_id: @principal.public_id,
      applied_by_operator_public_id: @approver.public_id,
    )
    release_case.build_principal_effect(
      principal_public_id: @principal.public_id,
      access_blocking: true,
      effective_at: Time.current,
    )
    EnforcementCaseApplyOperation.call(
      enforcement_case: release_case,
      actor_operator_public_id: @approver.public_id,
    )
    appeal_case = AppEnforcementCase.create!(
      kind: "security_lock",
      duration_mode: "indefinite",
      visibility: "visible",
      release_mode: "verification_required",
      effective_at: Time.current,
      reason_code: "security_incident",
      principal_public_id: @principal.public_id,
      applied_by_operator_public_id: @approver.public_id,
      state: "draft",
    )
    appeal = AppEnforcementAppeal.create!(
      enforcement_case: appeal_case,
      reason_code: "incorrect_decision",
      statement: "Standby appeal review test request",
      submitted_at: Time.current,
    )

    freshness_at = Time.current.change(usec: 0)
    @operator_token.update!(
      last_step_up_at: freshness_at,
      last_step_up_scope: "enforcement_case_apply",
      last_step_up_aal: "aal2",
      last_step_up_method: "passkey",
      last_step_up_phishing_resistant: true,
      last_step_up_user_verified: true,
      last_step_up_credential_ref: "standby-enforcement-step-up-credential",
      last_step_up_full_reauthentication: false,
      last_step_up_session_public_id: @operator_token.public_id,
      last_step_up_purpose: "step_up",
      last_step_up_audience: "step_up:org",
    )
    transaction_count = OperatorStepUpCeremonyTransaction.where(actor_ref: @operator.public_id).count
    case_count = AppEnforcementCase.count
    base_access = AuthenticationToken.encode(
      @operator,
      host: @host,
      session_public_id: @operator_token.public_id,
      resource_type: "operator",
      jwt_issuer_id: "surface:BASE_ORG",
      authentication_context: AuthenticationContextValue::STANDBY_KEY,
    )
    headers = {
      "Authorization" => "Bearer #{base_access}",
      "Client-Agent" => "Mozilla/5.0",
      "Host" => @host,
      "X-TEST-CURRENT-STAFF" => @operator.id.to_s,
      "X-TEST-SESSION-PUBLIC-ID" => @operator_token.public_id,
    }
    rp_client = OidcClientRegistry.find!("base-org-ww")
    rp_root = @operator_token.reload
    rp_root.rotate_refresh_token! unless rp_root.device_session.current_refresh_token_id
    rp_grant = OpOrgGrant.find_by(
      device_session_id: rp_root.device_session_id,
      oidc_client_id: rp_client.client_id,
      revoked_at: nil,
    )
    rp_grant ||= OpOrgGrant.create!(
      authentication_epoch: 0,
      operator_token: rp_root,
      oidc_client_id: rp_client.client_id,
      oidc_scope: "openid profile",
      oidc_jti: SecureRandom.uuid,
      oidc_nonce: SecureRandom.hex(16),
      oidc_auth_time: OpOrgGrant.database_now,
      refresh_token_expires_at: OpOrgGrant.database_now + 10.minutes,
    )
    rp_enrollment = RpCallbackCommitter.call(
      cell: RpCellBinding.for_client("base-org-ww"), issuer: OidcIssuer.for_client(rp_client),
      subject: OidcSubject.for(@operator, resource_type: "operator"), sid: rp_grant.public_id,
      absolute_expires_at: 1.hour.from_now,
    )

    assert_predicate rp_enrollment, :success?
    cookies[OidcRpBrowserCredentialContract::SESSION_COOKIE] = rp_enrollment.session.public_id
    rp_access = AuthenticationTokenService.encode(
      @operator,
      host: @host,
      resource_type: "operator",
      session_public_id: rp_root.public_id,
      base_session_public_id: rp_root.public_id,
      oidc_sid: rp_grant.public_id,
      oidc_jti: rp_grant.oidc_jti,
      expires_at: OpOrgGrant.database_now + 10.minutes,
      scopes: %w(openid profile),
      issuer: OidcIssuer.for_client(rp_client),
      audiences: [rp_client.aud],
      jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(rp_client),
      subject: OidcSubject.for(@operator, resource_type: "operator"),
      client_id: rp_client.client_id,
      authentication_context: AuthenticationContextValue::STANDBY_KEY,
    )
    headers["Cookie"] = [
      "#{AuthenticationBase::ACCESS_COOKIE_KEY}=#{Rack::Utils.escape(base_access)}",
      "#{OidcRpBrowserCredentialContract::ACCESS_COOKIE}=#{Rack::Utils.escape(rp_access)}",
      "#{OidcRpBrowserCredentialContract::REFRESH_COOKIE}=#{Rack::Utils.escape(rp_grant.issue_refresh_token!)}",
      "#{OidcRpBrowserCredentialContract::SESSION_COOKIE}=#{Rack::Utils.escape(rp_enrollment.session.public_id)}",
    ].join("; ")
    headers["HTTP_COOKIE"] = headers.fetch("Cookie")

    get(
      new_base_org_support_app_enforcement_case_url(
        host: @host,
        principal_public_id: @principal.public_id,
      ),
      headers: headers,
      as: :json,
    )

    assert_response :forbidden

    post(
      base_org_support_app_enforcement_cases_url(host: @host),
      params: { enforcement_case: { kind: "cooldown", principal_public_id: @principal.public_id } },
      headers: headers.merge(
        "Origin" => request.base_url,
        "Sec-Fetch-Site" => "same-origin",
        "Sec-Fetch-Mode" => "navigate",
        "Sec-Fetch-Dest" => "document",
      ),
      as: :json,
    )

    assert_response :forbidden

    @operator_token.update!(last_step_up_scope: "enforcement_case_approve")
    get(
      new_base_org_support_app_enforcement_case_approval_url(approval_case.public_id, host: @host),
      headers: headers,
      as: :json,
    )

    assert_response :forbidden
    assert_equal "pending_approval", approval_case.reload.state
    assert_nil approval_case.approved_by_operator_public_id

    post(
      base_org_support_app_enforcement_case_approval_url(approval_case.public_id, host: @host),
      params: { principal_effect: { access_blocking: true } },
      headers: headers.merge(
        "Origin" => request.base_url,
        "Sec-Fetch-Site" => "same-origin",
        "Sec-Fetch-Mode" => "navigate",
        "Sec-Fetch-Dest" => "document",
      ),
      as: :json,
    )

    assert_response :forbidden
    assert_equal "pending_approval", approval_case.reload.state
    assert_nil approval_case.approved_by_operator_public_id

    @operator_token.update!(last_step_up_scope: "enforcement_case_release")
    get(
      new_base_org_support_app_enforcement_case_release_url(release_case.public_id, host: @host),
      headers: headers,
      as: :json,
    )

    assert_response :forbidden
    assert_equal "active", release_case.reload.state
    assert_nil release_case.ended_at

    post(
      base_org_support_app_enforcement_case_release_url(release_case.public_id, host: @host),
      params: { reason: "revoked" },
      headers: headers.merge(
        "Origin" => request.base_url,
        "Sec-Fetch-Site" => "same-origin",
        "Sec-Fetch-Mode" => "navigate",
        "Sec-Fetch-Dest" => "document",
      ),
      as: :json,
    )

    assert_response :forbidden
    assert_equal "active", release_case.reload.state
    assert_nil release_case.ended_at

    @operator_token.update!(last_step_up_scope: "enforcement_case_review_appeal")
    get(
      new_base_org_support_app_enforcement_case_appeal_review_url(appeal_case.public_id, host: @host),
      headers: headers,
      as: :json,
    )

    assert_response :forbidden
    assert_equal "submitted", appeal.reload.state

    post(
      base_org_support_app_enforcement_case_appeal_review_url(appeal_case.public_id, host: @host),
      params: { resolution_code: "rejected" },
      headers: headers.merge(
        "Origin" => request.base_url,
        "Sec-Fetch-Site" => "same-origin",
        "Sec-Fetch-Mode" => "navigate",
        "Sec-Fetch-Dest" => "document",
      ),
      as: :json,
    )

    assert_response :forbidden
    assert_equal "submitted", appeal.reload.state
    assert_equal(
      [case_count, freshness_at, AuthenticationContextValue::STANDBY_KEY, transaction_count],
      [
        AppEnforcementCase.count,
        @operator_token.reload.last_step_up_at,
        @operator_token.authentication_context,
        OperatorStepUpCeremonyTransaction.where(actor_ref: @operator.public_id).count,
      ],
    )
  end

  test "Standby cannot grant or revoke capabilities despite fresh matching Step-Up" do
    [OperatorCapabilityGrant::IAM_CAPABILITY_READ,
     OperatorCapabilityGrant::IAM_CAPABILITY_GRANT,
     OperatorCapabilityGrant::IAM_CAPABILITY_REVOKE,
     OperatorCapabilityGrant::SUPPORT_ACCOUNT_READ_APP,
     OperatorCapabilityGrant::SUPPORT_ACCOUNT_READ_COM,].each do |capability|
      OperatorCapabilityGrant.create!(
        operator: @operator,
        origin: "bootstrap",
        capability: capability,
        reason_code: "bootstrap",
        starts_at: 1.minute.ago,
        expires_at: 1.day.from_now,
      )
    end
    grantee = Operator.create!(
      security_mode_id: SecurityModeConfigurable::ADVANCED,
      status_id: OperatorStatus::ACTIVE,
      visibility_id: OperatorVisibility::STAFF,
    )
    grant_to_revoke = OperatorCapabilityGrant.create!(
      operator: grantee,
      granted_by_operator: @approver,
      origin: "grant",
      capability: OperatorCapabilityGrant::SUPPORT_ACCOUNT_READ_COM,
      reason_code: "duty_assignment",
      starts_at: 1.minute.ago,
      expires_at: 1.day.from_now,
    )
    freshness_at = Time.current.change(usec: 0)
    @operator_token.update!(
      last_step_up_at: freshness_at,
      last_step_up_scope: "operator_capability",
      last_step_up_aal: "aal1",
      last_step_up_method: "passkey",
      last_step_up_phishing_resistant: true,
      last_step_up_user_verified: true,
      last_step_up_credential_ref: OperatorPasskey.find_by!(staff_id: @operator.id).external_id,
      last_step_up_full_reauthentication: false,
      last_step_up_session_public_id: @operator_token.public_id,
      last_step_up_purpose: "step_up",
      last_step_up_audience: "step_up:org",
    )
    rp_client = OidcClientRegistry.find!("base-org-ww")
    rp_root = @operator_token.reload
    rp_root.rotate_refresh_token! unless rp_root.device_session.current_refresh_token_id
    rp_grant = OpOrgGrant.find_by(
      device_session_id: rp_root.device_session_id,
      oidc_client_id: rp_client.client_id,
      revoked_at: nil,
    )
    rp_grant ||= OpOrgGrant.create!(
      authentication_epoch: 0,
      operator_token: rp_root,
      oidc_client_id: rp_client.client_id,
      oidc_scope: "openid profile",
      oidc_jti: SecureRandom.uuid,
      oidc_nonce: SecureRandom.hex(16),
      oidc_auth_time: OpOrgGrant.database_now,
      refresh_token_expires_at: OpOrgGrant.database_now + 10.minutes,
    )
    base_access = AuthenticationToken.encode(
      @operator,
      host: @host,
      session_public_id: @operator_token.public_id,
      resource_type: "operator",
      jwt_issuer_id: "surface:BASE_ORG",
      authentication_context: AuthenticationContextValue::STANDBY_KEY,
    )
    rp_enrollment = RpCallbackCommitter.call(
      cell: RpCellBinding.for_client("base-org-ww"), issuer: OidcIssuer.for_client(rp_client),
      subject: OidcSubject.for(@operator, resource_type: "operator"), sid: rp_grant.public_id,
      absolute_expires_at: 1.hour.from_now,
    )

    assert_predicate rp_enrollment, :success?
    cookies[OidcRpBrowserCredentialContract::SESSION_COOKIE] = rp_enrollment.session.public_id
    rp_access = AuthenticationTokenService.encode(
      @operator,
      host: @host,
      resource_type: "operator",
      session_public_id: rp_root.public_id,
      base_session_public_id: rp_root.public_id,
      oidc_sid: rp_grant.public_id,
      oidc_jti: rp_grant.oidc_jti,
      expires_at: OpOrgGrant.database_now + 10.minutes,
      scopes: %w(openid profile),
      issuer: OidcIssuer.for_client(rp_client),
      audiences: [rp_client.aud],
      jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(rp_client),
      subject: OidcSubject.for(@operator, resource_type: "operator"),
      client_id: rp_client.client_id,
      authentication_context: AuthenticationContextValue::STANDBY_KEY,
    )
    headers = {
      "Authorization" => "Bearer #{base_access}",
      "Client-Agent" => "Mozilla/5.0",
      "Host" => @host,
      "Cookie" => [
        "#{AuthenticationBase::ACCESS_COOKIE_KEY}=#{Rack::Utils.escape(base_access)}",
        "#{OidcRpBrowserCredentialContract::ACCESS_COOKIE}=#{Rack::Utils.escape(rp_access)}",
        "#{OidcRpBrowserCredentialContract::REFRESH_COOKIE}=#{Rack::Utils.escape(rp_grant.issue_refresh_token!)}",
        "#{OidcRpBrowserCredentialContract::SESSION_COOKIE}=#{Rack::Utils.escape(rp_enrollment.session.public_id)}",
      ].join("; "),
    }
    headers["HTTP_COOKIE"] = headers.fetch("Cookie")
    grant_count = OperatorCapabilityGrant.count
    ceremonies_before = OperatorStepUpCeremonyTransaction.where(actor_ref: @operator.public_id).count
    https!

    get new_base_org_iam_grant_url(ri: "jp", host: @host), headers: headers

    assert_response :forbidden

    post(
      base_org_iam_grants_url(host: @host),
      params: {
        operator_public_id: grantee.public_id,
        capability: OperatorCapabilityGrant::SUPPORT_ACCOUNT_READ_APP,
        reason_code: "duty_assignment",
        duration_days: "30",
        operation_id: SecureRandom.uuid,
      },
      headers: headers.merge(
        "Origin" => "https://#{@host}",
        "Sec-Fetch-Site" => "same-origin",
        "Sec-Fetch-Mode" => "navigate",
        "Sec-Fetch-Dest" => "document",
      ),
    )

    assert_response :forbidden

    post(
      base_org_iam_grant_revocation_url(grant_to_revoke.public_id, host: @host),
      params: { reason_code: "duty_assignment", operation_id: SecureRandom.uuid },
      headers: headers.merge(
        "Origin" => "https://#{@host}",
        "Sec-Fetch-Site" => "same-origin",
        "Sec-Fetch-Mode" => "navigate",
        "Sec-Fetch-Dest" => "document",
      ),
    )

    assert_response :forbidden
    assert_equal grant_count, OperatorCapabilityGrant.count
    assert_nil grant_to_revoke.reload.revoked_at
    assert_equal(
      [freshness_at, AuthenticationContextValue::STANDBY_KEY, ceremonies_before],
      [
        @operator_token.reload.last_step_up_at,
        @operator_token.authentication_context,
        OperatorStepUpCeremonyTransaction.where(actor_ref: @operator.public_id).count,
      ],
    )
  end

  test "Normal and Standby cannot write a Telephone registration without the RP owner boundary" do
    clear_enqueued_jobs
    https!
    host!(@host)
    @operator_token.update!(authentication_context: AuthenticationContextValue::NORMAL_KEY)
    freshness_at = Time.at(OpOrgGrant.database_now.to_i).utc
    _verification, verification_cookie = OperatorVerification.issue_for_token!(token: @operator_token)
    cookies[OperatorVerification.cookie_name] = verification_cookie
    rp_client = OidcClientRegistry.find!("base-org-ww")
    rp_root = @operator_token.reload
    rp_root.rotate_refresh_token! unless rp_root.device_session_record.current_refresh_token_id
    rp_grant = OpOrgGrant.create!(
      authentication_epoch: 0,
      operator_token: rp_root,
      oidc_client_id: rp_client.client_id,
      oidc_scope: "openid profile",
      oidc_jti: SecureRandom.uuid,
      oidc_nonce: SecureRandom.hex(16),
      oidc_auth_time: freshness_at,
      oidc_acr: StepUpEvidenceResolver::STEP_UP_ACR,
      oidc_amr: JSON.generate(["passkey"]),
      refresh_token_expires_at: OpOrgGrant.database_now + 10.minutes,
    )
    headers = (begin
      authentication_context = AuthenticationContextValue::NORMAL_KEY
      base_access = AuthenticationToken.encode(
        @operator,
        host: @host,
        session_public_id: @operator_token.public_id,
        resource_type: "operator",
        jwt_issuer_id: "surface:BASE_ORG",
        authentication_context: authentication_context,
      )
      rp_enrollment = RpCallbackCommitter.call(
        cell: RpCellBinding.for_client("base-org-ww"), issuer: OidcIssuer.for_client(rp_client),
        subject: OidcSubject.for(@operator, resource_type: "operator"), sid: rp_grant.public_id,
        absolute_expires_at: 1.hour.from_now,
      )

      assert_predicate rp_enrollment, :success?
      cookies[OidcRpBrowserCredentialContract::SESSION_COOKIE] = rp_enrollment.session.public_id
      rp_access = AuthenticationTokenService.encode(
        @operator,
        host: @host,
        resource_type: "operator",
        session_public_id: rp_root.public_id,
        base_session_public_id: rp_root.public_id,
        oidc_sid: rp_grant.public_id,
        oidc_jti: rp_grant.oidc_jti,
        expires_at: OpOrgGrant.database_now + 10.minutes,
        scopes: %w(openid profile),
        issuer: OidcIssuer.for_client(rp_client),
        audiences: [rp_client.aud],
        jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(rp_client),
        subject: OidcSubject.for(@operator, resource_type: "operator"),
        client_id: rp_client.client_id,
        acr: rp_grant.oidc_acr, amr: ["passkey"], auth_time: freshness_at,
        authentication_context: authentication_context,
      )
      cookies[AuthenticationBase::ACCESS_COOKIE_KEY] = base_access
      cookies[OidcRpBrowserCredentialContract::ACCESS_COOKIE] = rp_access
      cookies[OidcRpBrowserCredentialContract::REFRESH_COOKIE] = rp_grant.issue_refresh_token!
      {
        "Authorization" => "Bearer #{base_access}",
        "Client-Agent" => "Mozilla/5.0",
        "Host" => @host,
        "Origin" => "https://#{@host}",
        "Sec-Fetch-Site" => "same-origin",
        "Sec-Fetch-Mode" => "navigate",
        "Sec-Fetch-Dest" => "document",
      }
    end)
    TurnstileVerifierStub.challenge_enabled = true
    TurnstileVerifierStub.challenge_response = { "success" => true }
    ceremonies_before = OperatorStepUpCeremonyTransaction.where(actor_ref: @operator.public_id).count
    https!

    before = [OperatorTelephone.count, OperatorTelephoneCeremonyTransaction.count, enqueued_jobs.size]
    post(
      base_org_identity_telephones_registration_url(ri: "jp", host: @host),
      params: { staff_telephone: { raw_number: "+15558675332" } },
      headers: headers,
    )

    assert_response :service_unavailable
    assert_equal I18n.t("auth.rp_feature_unavailable"), response.body
    assert_equal before, [OperatorTelephone.count, OperatorTelephoneCeremonyTransaction.count, enqueued_jobs.size]

    @operator_token.update!(authentication_context: AuthenticationContextValue::STANDBY_KEY)
    standby_headers = (begin
      authentication_context = AuthenticationContextValue::STANDBY_KEY
      base_access = AuthenticationToken.encode(
        @operator,
        host: @host,
        session_public_id: @operator_token.public_id,
        resource_type: "operator",
        jwt_issuer_id: "surface:BASE_ORG",
        authentication_context: authentication_context,
      )
      rp_access = AuthenticationTokenService.encode(
        @operator,
        host: @host,
        resource_type: "operator",
        session_public_id: rp_root.public_id,
        base_session_public_id: rp_root.public_id,
        oidc_sid: rp_grant.public_id,
        oidc_jti: rp_grant.oidc_jti,
        expires_at: OpOrgGrant.database_now + 10.minutes,
        scopes: %w(openid profile),
        issuer: OidcIssuer.for_client(rp_client),
        audiences: [rp_client.aud],
        jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(rp_client),
        subject: OidcSubject.for(@operator, resource_type: "operator"),
        client_id: rp_client.client_id,
        acr: rp_grant.oidc_acr, amr: ["passkey"], auth_time: freshness_at,
        authentication_context: authentication_context,
      )
      cookies[AuthenticationBase::ACCESS_COOKIE_KEY] = base_access
      cookies[OidcRpBrowserCredentialContract::ACCESS_COOKIE] = rp_access
      cookies[OidcRpBrowserCredentialContract::REFRESH_COOKIE] = rp_grant.issue_refresh_token!
      {
        "Authorization" => "Bearer #{base_access}",
        "Client-Agent" => "Mozilla/5.0",
        "Host" => @host,
        "Origin" => "https://#{@host}",
        "Sec-Fetch-Site" => "same-origin",
        "Sec-Fetch-Mode" => "navigate",
        "Sec-Fetch-Dest" => "document",
      }
    end)

    post(
      base_org_identity_telephones_registration_url(ri: "jp", host: @host),
      params: { staff_telephone: { raw_number: "+15558675332" } },
      headers: standby_headers,
    )

    assert_response :forbidden
    assert_equal before, [OperatorTelephone.count, OperatorTelephoneCeremonyTransaction.count, enqueued_jobs.size]
    assert_equal ceremonies_before, OperatorStepUpCeremonyTransaction.where(actor_ref: @operator.public_id).count
  end

  test "Normal can manage owned contacts and Standby cannot update or remove them" do
    email_to_update = OperatorEmail.create!(
      staff: @operator,
      address: "standby-contact-update-#{SecureRandom.hex(6)}@example.com",
      staff_identity_email_status_id: OperatorEmailStatus::VERIFIED,
      confirm_policy: "1",
      promotional: true,
      notifiable: false,
    )
    email_to_remove = OperatorEmail.create!(
      staff: @operator,
      address: "standby-contact-remove-#{SecureRandom.hex(6)}@example.com",
      staff_identity_email_status_id: OperatorEmailStatus::VERIFIED,
      confirm_policy: "1",
      promotional: true,
      notifiable: false,
    )
    normal_telephone = @operator.staff_telephones.create!(
      raw_number: "+15558675340", confirm_policy: true, confirm_using_mfa: true,
    )
    standby_telephone = @operator.staff_telephones.create!(
      raw_number: "+15558675341", confirm_policy: true, confirm_using_mfa: true,
    )
    freshness_at = Time.at(OpOrgGrant.database_now.to_i).utc
    @operator_token.update!(authentication_context: AuthenticationContextValue::NORMAL_KEY)
    rp_client = OidcClientRegistry.find!("base-org-ww")
    rp_root = @operator_token.reload
    rp_root.rotate_refresh_token! unless rp_root.device_session_record.current_refresh_token_id
    rp_grant = OpOrgGrant.create!(
      authentication_epoch: 0,
      operator_token: rp_root,
      oidc_client_id: rp_client.client_id,
      oidc_scope: "openid profile",
      oidc_jti: SecureRandom.uuid,
      oidc_nonce: SecureRandom.hex(16),
      oidc_auth_time: freshness_at,
      oidc_acr: StepUpEvidenceResolver::STEP_UP_ACR,
      oidc_amr: JSON.generate(["passkey"]),
      refresh_token_expires_at: OpOrgGrant.database_now + 10.minutes,
    )
    https!
    host!(@host)
    TurnstileVerifierStub.challenge_enabled = true
    TurnstileVerifierStub.challenge_response = { "success" => true }
    normal_headers = (begin
      authentication_context = AuthenticationContextValue::NORMAL_KEY
      base_access = AuthenticationToken.encode(
        @operator,
        host: @host,
        session_public_id: @operator_token.public_id,
        resource_type: "operator",
        jwt_issuer_id: "surface:BASE_ORG",
        authentication_context: authentication_context,
      )
      rp_enrollment = RpCallbackCommitter.call(
        cell: RpCellBinding.for_client("base-org-ww"), issuer: OidcIssuer.for_client(rp_client),
        subject: OidcSubject.for(@operator, resource_type: "operator"), sid: rp_grant.public_id,
        absolute_expires_at: 1.hour.from_now,
      )

      assert_predicate rp_enrollment, :success?
      cookies[OidcRpBrowserCredentialContract::SESSION_COOKIE] = rp_enrollment.session.public_id
      rp_access = AuthenticationTokenService.encode(
        @operator,
        host: @host,
        resource_type: "operator",
        session_public_id: rp_root.public_id,
        base_session_public_id: rp_root.public_id,
        oidc_sid: rp_grant.public_id,
        oidc_jti: rp_grant.oidc_jti,
        expires_at: OpOrgGrant.database_now + 10.minutes,
        scopes: %w(openid profile),
        issuer: OidcIssuer.for_client(rp_client),
        audiences: [rp_client.aud],
        jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(rp_client),
        subject: OidcSubject.for(@operator, resource_type: "operator"),
        client_id: rp_client.client_id,
        acr: rp_grant.oidc_acr, amr: ["passkey"], auth_time: freshness_at,
        authentication_context: authentication_context,
      )
      cookies[AuthenticationBase::ACCESS_COOKIE_KEY] = base_access
      cookies[OidcRpBrowserCredentialContract::ACCESS_COOKIE] = rp_access
      cookies[OidcRpBrowserCredentialContract::REFRESH_COOKIE] = rp_grant.issue_refresh_token!
      {
        "Origin" => "https://#{@host}",
        "Sec-Fetch-Site" => "same-origin",
        "Sec-Fetch-Mode" => "navigate",
        "Sec-Fetch-Dest" => "document",
      }
    end)

    patch(
      base_org_identity_email_url(email_to_update.public_id, ri: "jp", host: @host),
      params: { staff_email: { promotional: false, notifiable: true } },
      headers: normal_headers,
    )

    assert_equal 303, response.status
    assert_not email_to_update.reload.promotional
    assert_equal AuthenticationContextValue::NORMAL_KEY, @operator_token.reload.authentication_context

    get(
      base_org_identity_withdrawal_url(ri: "jp", host: @host),
      headers: (begin
        authentication_context = AuthenticationContextValue::NORMAL_KEY
        base_access = AuthenticationToken.encode(
          @operator,
          host: @host,
          session_public_id: @operator_token.public_id,
          resource_type: "operator",
          jwt_issuer_id: "surface:BASE_ORG",
          authentication_context: authentication_context,
        )
        rp_access = AuthenticationTokenService.encode(
          @operator,
          host: @host,
          resource_type: "operator",
          session_public_id: rp_root.public_id,
          base_session_public_id: rp_root.public_id,
          oidc_sid: rp_grant.public_id,
          oidc_jti: rp_grant.oidc_jti,
          expires_at: OpOrgGrant.database_now + 10.minutes,
          scopes: %w(openid profile),
          issuer: OidcIssuer.for_client(rp_client),
          audiences: [rp_client.aud],
          jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(rp_client),
          subject: OidcSubject.for(@operator, resource_type: "operator"),
          client_id: rp_client.client_id,
          acr: rp_grant.oidc_acr, amr: ["passkey"], auth_time: freshness_at,
          authentication_context: authentication_context,
        )
        cookies[AuthenticationBase::ACCESS_COOKIE_KEY] = base_access
        cookies[OidcRpBrowserCredentialContract::ACCESS_COOKIE] = rp_access
        cookies[OidcRpBrowserCredentialContract::REFRESH_COOKIE] = rp_grant.issue_refresh_token!
        {
          "Origin" => "https://#{@host}",
          "Sec-Fetch-Site" => "same-origin",
          "Sec-Fetch-Mode" => "navigate",
          "Sec-Fetch-Dest" => "document",
        }
      end),
    )

    assert_response :success

    delete(
      base_org_identity_telephone_url(normal_telephone.public_id, ri: "jp", host: @host),
      headers: (begin
        authentication_context = AuthenticationContextValue::NORMAL_KEY
        base_access = AuthenticationToken.encode(
          @operator,
          host: @host,
          session_public_id: @operator_token.public_id,
          resource_type: "operator",
          jwt_issuer_id: "surface:BASE_ORG",
          authentication_context: authentication_context,
        )
        rp_access = AuthenticationTokenService.encode(
          @operator,
          host: @host,
          resource_type: "operator",
          session_public_id: rp_root.public_id,
          base_session_public_id: rp_root.public_id,
          oidc_sid: rp_grant.public_id,
          oidc_jti: rp_grant.oidc_jti,
          expires_at: OpOrgGrant.database_now + 10.minutes,
          scopes: %w(openid profile),
          issuer: OidcIssuer.for_client(rp_client),
          audiences: [rp_client.aud],
          jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(rp_client),
          subject: OidcSubject.for(@operator, resource_type: "operator"),
          client_id: rp_client.client_id,
          acr: rp_grant.oidc_acr, amr: ["passkey"], auth_time: freshness_at,
          authentication_context: authentication_context,
        )
        cookies[AuthenticationBase::ACCESS_COOKIE_KEY] = base_access
        cookies[OidcRpBrowserCredentialContract::ACCESS_COOKIE] = rp_access
        cookies[OidcRpBrowserCredentialContract::REFRESH_COOKIE] = rp_grant.issue_refresh_token!
        {
          "Origin" => "https://#{@host}",
          "Sec-Fetch-Site" => "same-origin",
          "Sec-Fetch-Mode" => "navigate",
          "Sec-Fetch-Dest" => "document",
        }
      end),
    )

    assert_equal 303, response.status
    assert_not OperatorTelephone.exists?(normal_telephone.id)

    @operator_token.update!(authentication_context: AuthenticationContextValue::STANDBY_KEY)
    standby_headers = (begin
      authentication_context = AuthenticationContextValue::STANDBY_KEY
      base_access = AuthenticationToken.encode(
        @operator,
        host: @host,
        session_public_id: @operator_token.public_id,
        resource_type: "operator",
        jwt_issuer_id: "surface:BASE_ORG",
        authentication_context: authentication_context,
      )
      rp_access = AuthenticationTokenService.encode(
        @operator,
        host: @host,
        resource_type: "operator",
        session_public_id: rp_root.public_id,
        base_session_public_id: rp_root.public_id,
        oidc_sid: rp_grant.public_id,
        oidc_jti: rp_grant.oidc_jti,
        expires_at: OpOrgGrant.database_now + 10.minutes,
        scopes: %w(openid profile),
        issuer: OidcIssuer.for_client(rp_client),
        audiences: [rp_client.aud],
        jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(rp_client),
        subject: OidcSubject.for(@operator, resource_type: "operator"),
        client_id: rp_client.client_id,
        acr: rp_grant.oidc_acr, amr: ["passkey"], auth_time: freshness_at,
        authentication_context: authentication_context,
      )
      cookies[AuthenticationBase::ACCESS_COOKIE_KEY] = base_access
      cookies[OidcRpBrowserCredentialContract::ACCESS_COOKIE] = rp_access
      cookies[OidcRpBrowserCredentialContract::REFRESH_COOKIE] = rp_grant.issue_refresh_token!
      {
        "Origin" => "https://#{@host}",
        "Sec-Fetch-Site" => "same-origin",
        "Sec-Fetch-Mode" => "navigate",
        "Sec-Fetch-Dest" => "document",
      }
    end)

    patch(
      base_org_identity_email_url(email_to_update.public_id, ri: "jp", host: @host),
      params: { staff_email: { promotional: true, notifiable: false } },
      headers: standby_headers,
    )

    assert_equal 403, response.status
    assert_not email_to_update.reload.promotional
    assert email_to_update.notifiable

    delete(
      base_org_identity_email_url(email_to_remove.public_id, ri: "jp", host: @host),
      headers: standby_headers,
    )

    assert_equal 403, response.status
    assert_predicate email_to_remove.reload, :persisted?

    delete(
      base_org_identity_telephone_url(standby_telephone.public_id, ri: "jp", host: @host),
      headers: (begin
        authentication_context = AuthenticationContextValue::STANDBY_KEY
        base_access = AuthenticationToken.encode(
          @operator,
          host: @host,
          session_public_id: @operator_token.public_id,
          resource_type: "operator",
          jwt_issuer_id: "surface:BASE_ORG",
          authentication_context: authentication_context,
        )
        rp_access = AuthenticationTokenService.encode(
          @operator,
          host: @host,
          resource_type: "operator",
          session_public_id: rp_root.public_id,
          base_session_public_id: rp_root.public_id,
          oidc_sid: rp_grant.public_id,
          oidc_jti: rp_grant.oidc_jti,
          expires_at: OpOrgGrant.database_now + 10.minutes,
          scopes: %w(openid profile),
          issuer: OidcIssuer.for_client(rp_client),
          audiences: [rp_client.aud],
          jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(rp_client),
          subject: OidcSubject.for(@operator, resource_type: "operator"),
          client_id: rp_client.client_id,
          acr: rp_grant.oidc_acr, amr: ["passkey"], auth_time: freshness_at,
          authentication_context: authentication_context,
        )
        cookies[AuthenticationBase::ACCESS_COOKIE_KEY] = base_access
        cookies[OidcRpBrowserCredentialContract::ACCESS_COOKIE] = rp_access
        cookies[OidcRpBrowserCredentialContract::REFRESH_COOKIE] = rp_grant.issue_refresh_token!
        {
          "Origin" => "https://#{@host}",
          "Sec-Fetch-Site" => "same-origin",
          "Sec-Fetch-Mode" => "navigate",
          "Sec-Fetch-Dest" => "document",
        }
      end),
    )

    assert_equal 403, response.status
    assert_predicate standby_telephone.reload, :persisted?

    get(
      base_org_identity_withdrawal_url(ri: "jp", host: @host),
      headers: (begin
        authentication_context = AuthenticationContextValue::STANDBY_KEY
        base_access = AuthenticationToken.encode(
          @operator,
          host: @host,
          session_public_id: @operator_token.public_id,
          resource_type: "operator",
          jwt_issuer_id: "surface:BASE_ORG",
          authentication_context: authentication_context,
        )
        rp_access = AuthenticationTokenService.encode(
          @operator,
          host: @host,
          resource_type: "operator",
          session_public_id: rp_root.public_id,
          base_session_public_id: rp_root.public_id,
          oidc_sid: rp_grant.public_id,
          oidc_jti: rp_grant.oidc_jti,
          expires_at: OpOrgGrant.database_now + 10.minutes,
          scopes: %w(openid profile),
          issuer: OidcIssuer.for_client(rp_client),
          audiences: [rp_client.aud],
          jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(rp_client),
          subject: OidcSubject.for(@operator, resource_type: "operator"),
          client_id: rp_client.client_id,
          acr: rp_grant.oidc_acr, amr: ["passkey"], auth_time: freshness_at,
          authentication_context: authentication_context,
        )
        cookies[AuthenticationBase::ACCESS_COOKIE_KEY] = base_access
        cookies[OidcRpBrowserCredentialContract::ACCESS_COOKIE] = rp_access
        cookies[OidcRpBrowserCredentialContract::REFRESH_COOKIE] = rp_grant.issue_refresh_token!
        {
          "Origin" => "https://#{@host}",
          "Sec-Fetch-Site" => "same-origin",
          "Sec-Fetch-Mode" => "navigate",
          "Sec-Fetch-Dest" => "document",
        }
      end),
    )

    assert_response :forbidden
    assert_equal I18n.t("auth.step_up.emergency_unavailable"), response.body
    assert_equal AuthenticationContextValue::STANDBY_KEY, @operator_token.reload.authentication_context
    assert_equal freshness_at, rp_grant.reload.oidc_auth_time
  end

  test "Standby cannot start Step-Up or authenticator bootstrap from Base" do
    OperatorPasskey.where(staff_id: @operator.id).delete_all
    signed_pt = (begin
      verifier = ActiveSupport::MessageVerifier.new(
        Rails.application.key_generator.generate_key("path_target_token", 32),
        digest: "SHA256",
        serializer: JSON,
        url_safe: true,
      )
      verifier.generate(
        {
          "flow" => "step_up.bootstrap",
          "surface" => "org",
          "session_nonce" => @operator_token.public_id,
          "pt" => "/identity/passkeys",
        },
        purpose: :path_target,
        expires_in: 15.minutes,
      )
    end)
    @operator_token.update!(authentication_context: AuthenticationContextValue::NORMAL_KEY)
    normal_headers = (begin
      authentication_context = AuthenticationContextValue::NORMAL_KEY
      rp_client = OidcClientRegistry.find!("base-org-ww")
      rp_root = @operator_token.reload
      rp_root.rotate_refresh_token! unless rp_root.device_session.current_refresh_token_id
      rp_grant = (begin
        OpOrgGrant.find_by(
          device_session_id: rp_root.device_session_id,
          oidc_client_id: rp_client.client_id,
          revoked_at: nil,
        ) || OpOrgGrant.create!(
          authentication_epoch: 0,
          operator_token: rp_root,
          oidc_client_id: rp_client.client_id,
          oidc_scope: "openid profile",
          oidc_jti: SecureRandom.uuid,
          oidc_nonce: SecureRandom.hex(16),
          oidc_auth_time: OpOrgGrant.database_now,
          refresh_token_expires_at: OpOrgGrant.database_now + 10.minutes,
        )
      end)
      base_access = AuthenticationToken.encode(
        @operator,
        host: @host,
        session_public_id: @operator_token.public_id,
        resource_type: "operator",
        jwt_issuer_id: "surface:BASE_ORG",
        authentication_context: authentication_context,
      )
      rp_enrollment = RpCallbackCommitter.call(
        cell: RpCellBinding.for_client("base-org-ww"), issuer: OidcIssuer.for_client(rp_client),
        subject: OidcSubject.for(@operator, resource_type: "operator"), sid: rp_grant.public_id,
        absolute_expires_at: 1.hour.from_now,
      )

      assert_predicate rp_enrollment, :success?
      cookies[OidcRpBrowserCredentialContract::SESSION_COOKIE] = rp_enrollment.session.public_id
      rp_access = AuthenticationTokenService.encode(
        @operator,
        host: @host,
        resource_type: "operator",
        session_public_id: rp_root.public_id,
        base_session_public_id: rp_root.public_id,
        oidc_sid: rp_grant.public_id,
        oidc_jti: rp_grant.oidc_jti,
        expires_at: OpOrgGrant.database_now + 10.minutes,
        scopes: %w(openid profile),
        issuer: OidcIssuer.for_client(rp_client),
        audiences: [rp_client.aud],
        jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(rp_client),
        subject: OidcSubject.for(@operator, resource_type: "operator"),
        client_id: rp_client.client_id,
        authentication_context: authentication_context,
      )
      headers = {
        "Authorization" => "Bearer #{base_access}",
        "Client-Agent" => "Mozilla/5.0",
        "Host" => @host,
        "Origin" => "https://#{@host}",
        "Sec-Fetch-Site" => "same-origin",
        "Sec-Fetch-Mode" => "navigate",
        "Sec-Fetch-Dest" => "document",
        "Cookie" => [
          "#{AuthenticationBase::ACCESS_COOKIE_KEY}=#{Rack::Utils.escape(base_access)}",
          "#{OidcRpBrowserCredentialContract::ACCESS_COOKIE}=#{Rack::Utils.escape(rp_access)}",
          "#{OidcRpBrowserCredentialContract::REFRESH_COOKIE}=#{Rack::Utils.escape(rp_grant.issue_refresh_token!)}",
          "#{OidcRpBrowserCredentialContract::SESSION_COOKIE}=#{Rack::Utils.escape(rp_enrollment.session.public_id)}",
        ].join("; "),
      }
      headers["HTTP_COOKIE"] = headers.fetch("Cookie")
      headers
    end)
    before = [OperatorStepUpCeremonyTransaction.count, OperatorAuthAdmissionBinding.count]
    https!

    get(
      base_org_verification_setup_url(
        scope: "settings_passkey", pt: signed_pt, ri: "jp", host: @host,
      ),
      headers: normal_headers,
    )

    assert_response :success
    assert_includes response.body, "base/org/verification/setups/show"
    assert_equal before, [OperatorStepUpCeremonyTransaction.count, OperatorAuthAdmissionBinding.count]

    @operator_token.update!(authentication_context: AuthenticationContextValue::STANDBY_KEY)
    headers = (begin
      authentication_context = AuthenticationContextValue::STANDBY_KEY
      rp_client = OidcClientRegistry.find!("base-org-ww")
      rp_root = @operator_token.reload
      rp_root.rotate_refresh_token! unless rp_root.device_session.current_refresh_token_id
      rp_grant = (begin
        OpOrgGrant.find_by(
          device_session_id: rp_root.device_session_id,
          oidc_client_id: rp_client.client_id,
          revoked_at: nil,
        ) || OpOrgGrant.create!(
          authentication_epoch: 0,
          operator_token: rp_root,
          oidc_client_id: rp_client.client_id,
          oidc_scope: "openid profile",
          oidc_jti: SecureRandom.uuid,
          oidc_nonce: SecureRandom.hex(16),
          oidc_auth_time: OpOrgGrant.database_now,
          refresh_token_expires_at: OpOrgGrant.database_now + 10.minutes,
        )
      end)
      base_access = AuthenticationToken.encode(
        @operator,
        host: @host,
        session_public_id: @operator_token.public_id,
        resource_type: "operator",
        jwt_issuer_id: "surface:BASE_ORG",
        authentication_context: authentication_context,
      )
      rp_access = AuthenticationTokenService.encode(
        @operator,
        host: @host,
        resource_type: "operator",
        session_public_id: rp_root.public_id,
        base_session_public_id: rp_root.public_id,
        oidc_sid: rp_grant.public_id,
        oidc_jti: rp_grant.oidc_jti,
        expires_at: OpOrgGrant.database_now + 10.minutes,
        scopes: %w(openid profile),
        issuer: OidcIssuer.for_client(rp_client),
        audiences: [rp_client.aud],
        jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(rp_client),
        subject: OidcSubject.for(@operator, resource_type: "operator"),
        client_id: rp_client.client_id,
        authentication_context: authentication_context,
      )
      headers = {
        "Authorization" => "Bearer #{base_access}",
        "Client-Agent" => "Mozilla/5.0",
        "Host" => @host,
        "Origin" => "https://#{@host}",
        "Sec-Fetch-Site" => "same-origin",
        "Sec-Fetch-Mode" => "navigate",
        "Sec-Fetch-Dest" => "document",
        "Cookie" => [
          "#{AuthenticationBase::ACCESS_COOKIE_KEY}=#{Rack::Utils.escape(base_access)}",
          "#{OidcRpBrowserCredentialContract::ACCESS_COOKIE}=#{Rack::Utils.escape(rp_access)}",
          "#{OidcRpBrowserCredentialContract::REFRESH_COOKIE}=#{Rack::Utils.escape(rp_grant.issue_refresh_token!)}",
          "#{OidcRpBrowserCredentialContract::SESSION_COOKIE}=#{Rack::Utils.escape(rp_enrollment.session.public_id)}",
        ].join("; "),
      }
      headers["HTTP_COOKIE"] = headers.fetch("Cookie")
      headers
    end)
    before = [
      OperatorStepUpCeremonyTransaction.count,
      OperatorAuthAdmissionBinding.count,
      @operator_token.reload.authentication_context,
      @operator_token.last_step_up_at,
    ]
    get(
      base_org_verification_url(scope: "settings_email", pt: signed_pt, ri: "jp", host: @host),
      headers: headers,
    )

    assert_response :forbidden
    assert_equal I18n.t("auth.step_up.emergency_unavailable"), response.body

    get(
      base_org_verification_setup_url(
        scope: "settings_passkey", pt: signed_pt, ri: "jp", host: @host,
      ),
      headers: headers,
    )

    assert_response :forbidden
    assert_equal I18n.t("auth.step_up.emergency_unavailable"), response.body

    post(
      base_org_verification_setup_url(scope: "settings_passkey", pt: signed_pt, ri: "jp", host: @host),
      params: { registration_method: "passkey" },
      headers: headers,
    )

    assert_response :forbidden
    assert_equal I18n.t("auth.step_up.emergency_unavailable"), response.body
    assert_equal before, [
      OperatorStepUpCeremonyTransaction.count,
      OperatorAuthAdmissionBinding.count,
      @operator_token.reload.authentication_context,
      @operator_token.last_step_up_at,
    ]
  end

  test "Standby cannot start Telephone registration despite fresh matching Step-Up" do
    clear_enqueued_jobs
    step_up_passkey = OperatorPasskey.find_by!(staff_id: @operator.id)
    freshness_at = Time.current.change(usec: 0)
    @operator_token.update!(
      last_step_up_at: freshness_at,
      last_step_up_scope: "settings_telephone",
      last_step_up_aal: "aal2",
      last_step_up_method: "passkey",
      last_step_up_phishing_resistant: true,
      last_step_up_user_verified: true,
      last_step_up_credential_ref: step_up_passkey.external_id,
      last_step_up_full_reauthentication: false,
      last_step_up_session_public_id: @operator_token.public_id,
      last_step_up_purpose: "step_up",
      last_step_up_audience: "step_up:org",
    )
    headers = (begin
      authentication_context = AuthenticationContextValue::STANDBY_KEY
      rp_client = OidcClientRegistry.find!("base-org-ww")
      rp_root = @operator_token.reload
      rp_root.rotate_refresh_token! unless rp_root.device_session.current_refresh_token_id
      rp_grant = (begin
        OpOrgGrant.find_by(
          device_session_id: rp_root.device_session_id,
          oidc_client_id: rp_client.client_id,
          revoked_at: nil,
        ) || OpOrgGrant.create!(
          authentication_epoch: 0,
          operator_token: rp_root,
          oidc_client_id: rp_client.client_id,
          oidc_scope: "openid profile",
          oidc_jti: SecureRandom.uuid,
          oidc_nonce: SecureRandom.hex(16),
          oidc_auth_time: OpOrgGrant.database_now,
          refresh_token_expires_at: OpOrgGrant.database_now + 10.minutes,
        )
      end)
      base_access = AuthenticationToken.encode(
        @operator,
        host: @host,
        session_public_id: @operator_token.public_id,
        resource_type: "operator",
        jwt_issuer_id: "surface:BASE_ORG",
        authentication_context: authentication_context,
      )
      rp_enrollment = RpCallbackCommitter.call(
        cell: RpCellBinding.for_client("base-org-ww"), issuer: OidcIssuer.for_client(rp_client),
        subject: OidcSubject.for(@operator, resource_type: "operator"), sid: rp_grant.public_id,
        absolute_expires_at: 1.hour.from_now,
      )

      assert_predicate rp_enrollment, :success?
      cookies[OidcRpBrowserCredentialContract::SESSION_COOKIE] = rp_enrollment.session.public_id
      rp_access = AuthenticationTokenService.encode(
        @operator,
        host: @host,
        resource_type: "operator",
        session_public_id: rp_root.public_id,
        base_session_public_id: rp_root.public_id,
        oidc_sid: rp_grant.public_id,
        oidc_jti: rp_grant.oidc_jti,
        expires_at: OpOrgGrant.database_now + 10.minutes,
        scopes: %w(openid profile),
        issuer: OidcIssuer.for_client(rp_client),
        audiences: [rp_client.aud],
        jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(rp_client),
        subject: OidcSubject.for(@operator, resource_type: "operator"),
        client_id: rp_client.client_id,
        authentication_context: authentication_context,
      )
      headers = {
        "Authorization" => "Bearer #{base_access}",
        "Client-Agent" => "Mozilla/5.0",
        "Host" => @host,
        "Origin" => "https://#{@host}",
        "Sec-Fetch-Site" => "same-origin",
        "Sec-Fetch-Mode" => "navigate",
        "Sec-Fetch-Dest" => "document",
        "Cookie" => [
          "#{AuthenticationBase::ACCESS_COOKIE_KEY}=#{Rack::Utils.escape(base_access)}",
          "#{OidcRpBrowserCredentialContract::ACCESS_COOKIE}=#{Rack::Utils.escape(rp_access)}",
          "#{OidcRpBrowserCredentialContract::REFRESH_COOKIE}=#{Rack::Utils.escape(rp_grant.issue_refresh_token!)}",
          "#{OidcRpBrowserCredentialContract::SESSION_COOKIE}=#{Rack::Utils.escape(rp_enrollment.session.public_id)}",
        ].join("; "),
      }
      headers["HTTP_COOKIE"] = headers.fetch("Cookie")
      headers
    end)
    before = [
      OperatorTelephone.count,
      OperatorTelephoneCeremonyTransaction.count,
      enqueued_jobs.size,
      freshness_at,
      AuthenticationContextValue::STANDBY_KEY,
    ]
    https!

    get(
      new_base_org_identity_telephones_registration_url(ri: "jp", host: @host),
      headers: headers,
    )

    assert_response :forbidden

    post(
      base_org_identity_telephones_registration_url(ri: "jp", host: @host),
      params: { staff_telephone: { raw_number: "+15558675342" } },
      headers: headers,
    )

    assert_response :forbidden
    assert_equal before, [
      OperatorTelephone.count,
      OperatorTelephoneCeremonyTransaction.count,
      enqueued_jobs.size,
      @operator_token.reload.last_step_up_at,
      @operator_token.authentication_context,
    ]
  end
end
