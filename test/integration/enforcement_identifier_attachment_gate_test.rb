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
    host = ENV.fetch("PUBLIC_BASE_SERVICE_URL", "base.app.localhost")
    host! host
    user = clients(:one)
    headers = app_headers_for(user, host: host)

    operator = operators(:one)
    the_case = AppEnforcementCase.new(
      kind: "cooldown", duration_mode: "timed", visibility: "visible", release_mode: "automatic",
      effective_at: Time.current, expires_at: 1.day.from_now, reason_code: "abuse",
      principal_public_id: "some_other_client_public_id", applied_by_operator_public_id: operator.public_id,
    )
    digest = EnforcementIdentifierDigest.for_email(realm: "app", value: "app_attach_blocked@example.com")
    the_case.identifier_effects.build(**digest, attachment_blocked: true, effective_at: Time.current)
    EnforcementCaseApplyOperation.call(enforcement_case: the_case)

    assert_no_difference("ClientEmail.count") do
      post base_app_identity_emails_registration_url(ri: "jp", host: host),
           params: { user_email: { address: "App_Attach_Blocked@Example.com" } },
           headers: headers
    end

    assert_response :unprocessable_content
  end

  test "app telephone attachment is rejected when blocked by an in-force attachment_blocked Identifier Effect" do
    host = ENV.fetch("PUBLIC_BASE_SERVICE_URL", "base.app.localhost")
    host! host
    user = clients(:one)
    headers = app_headers_for(user, host: host, scope: "settings_telephone")

    operator = operators(:one)
    the_case = AppEnforcementCase.new(
      kind: "cooldown", duration_mode: "timed", visibility: "visible", release_mode: "automatic",
      effective_at: Time.current, expires_at: 1.day.from_now, reason_code: "abuse",
      principal_public_id: "some_other_client_public_id", applied_by_operator_public_id: operator.public_id,
    )
    digest = EnforcementIdentifierDigest.for_telephone(realm: "app", value: "+15558675301")
    the_case.identifier_effects.build(**digest, attachment_blocked: true, effective_at: Time.current)
    EnforcementCaseApplyOperation.call(enforcement_case: the_case)

    assert_no_difference("ClientTelephone.count") do
      post base_app_identity_telephones_registration_url(ri: "jp", host: host),
           params: { user_telephone: { raw_number: "+15558675301" } },
           headers: headers
    end

    assert_response :unprocessable_content
  end

  test "com email attachment is rejected when blocked by an in-force attachment_blocked Identifier Effect" do
    host = ENV.fetch("PUBLIC_BASE_CORPORATE_URL", "base.com.localhost")
    host! host
    visitor = visitors(:reserved_visitor)
    headers = com_headers_for(visitor, host: host)

    operator = operators(:one)
    the_case = ComEnforcementCase.new(
      kind: "cooldown", duration_mode: "timed", visibility: "visible", release_mode: "automatic",
      effective_at: Time.current, expires_at: 1.day.from_now, reason_code: "abuse",
      principal_public_id: "some_other_visitor_public_id", applied_by_operator_public_id: operator.public_id,
    )
    digest = EnforcementIdentifierDigest.for_email(realm: "com", value: "com_attach_blocked@example.com")
    the_case.identifier_effects.build(**digest, attachment_blocked: true, effective_at: Time.current)
    EnforcementCaseApplyOperation.call(enforcement_case: the_case)

    assert_no_difference("VisitorEmail.count") do
      post base_com_identity_emails_registration_url(ri: "jp", host: host),
           params: { visitor_email: { address: "Com_Attach_Blocked@Example.com" } },
           headers: headers
    end

    assert_response :unprocessable_content
  end

  test "com telephone attachment is rejected when blocked by an in-force attachment_blocked Identifier Effect" do
    host = ENV.fetch("PUBLIC_BASE_CORPORATE_URL", "base.com.localhost")
    host! host
    visitor = visitors(:reserved_visitor)
    headers = com_headers_for(visitor, host: host, scope: "settings_telephone")

    operator = operators(:one)
    the_case = ComEnforcementCase.new(
      kind: "cooldown", duration_mode: "timed", visibility: "visible", release_mode: "automatic",
      effective_at: Time.current, expires_at: 1.day.from_now, reason_code: "abuse",
      principal_public_id: "some_other_visitor_public_id", applied_by_operator_public_id: operator.public_id,
    )
    digest = EnforcementIdentifierDigest.for_telephone(realm: "com", value: "+15558675302")
    the_case.identifier_effects.build(**digest, attachment_blocked: true, effective_at: Time.current)
    EnforcementCaseApplyOperation.call(enforcement_case: the_case)

    assert_no_difference("VisitorTelephone.count") do
      post base_com_identity_telephones_registration_url(ri: "jp", host: host),
           params: { user_telephone: { raw_number: "+15558675302" } },
           headers: headers
    end

    assert_response :unprocessable_content
  end

  test "org email attachment is rejected when blocked by an in-force attachment_blocked Identifier Effect" do
    host = ENV.fetch("PUBLIC_BASE_STAFF_URL", "base.org.localhost")
    host! host
    operator = operators(:one)
    headers = org_headers_for(operator, host: host)

    blocking_operator = operators(:one)
    the_case = OrgEnforcementCase.new(
      kind: "cooldown", duration_mode: "timed", visibility: "visible", release_mode: "automatic",
      effective_at: Time.current, expires_at: 1.day.from_now, reason_code: "abuse",
      principal_public_id: "some_other_operator_public_id",
      applied_by_operator_public_id: blocking_operator.public_id,
    )
    digest = EnforcementIdentifierDigest.for_email(realm: "org", value: "org_attach_blocked@example.com")
    the_case.identifier_effects.build(**digest, attachment_blocked: true, effective_at: Time.current)
    EnforcementCaseApplyOperation.call(enforcement_case: the_case)

    assert_no_difference("OperatorEmail.count") do
      post base_org_identity_emails_registration_url(ri: "jp", host: host),
           params: { staff_email: { address: "Org_Attach_Blocked@Example.com" } },
           headers: headers
    end

    assert_response :unprocessable_content
  end

  test "org telephone attachment is rejected when blocked by an in-force attachment_blocked Identifier Effect" do
    host = ENV.fetch("PUBLIC_BASE_STAFF_URL", "base.org.localhost")
    host! host
    operator = operators(:one)
    headers = org_headers_for(operator, host: host, scope: "settings_telephone")

    blocking_operator = operators(:one)
    the_case = OrgEnforcementCase.new(
      kind: "cooldown", duration_mode: "timed", visibility: "visible", release_mode: "automatic",
      effective_at: Time.current, expires_at: 1.day.from_now, reason_code: "abuse",
      principal_public_id: "some_other_operator_public_id",
      applied_by_operator_public_id: blocking_operator.public_id,
    )
    digest = EnforcementIdentifierDigest.for_telephone(realm: "org", value: "+15558675303")
    the_case.identifier_effects.build(**digest, attachment_blocked: true, effective_at: Time.current)
    EnforcementCaseApplyOperation.call(enforcement_case: the_case)

    assert_no_difference("OperatorTelephone.count") do
      post base_org_identity_telephones_registration_url(ri: "jp", host: host),
           params: { staff_telephone: { raw_number: "+15558675303" } },
           headers: headers
    end

    assert_response :unprocessable_content
  end

  private

  def app_headers_for(user, host:, scope: "settings_email")
    token = ClientToken.create!(
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
      last_step_up_scope: scope,
      last_step_up_aal: "aal2",
      last_step_up_method: "passkey",
      last_step_up_session_public_id: token.public_id,
      last_step_up_purpose: "step_up",
      last_step_up_audience: "step_up:app",
    )
    access_token = AuthenticationToken.encode(
      user, host: host, session_public_id: token.public_id,
            resource_type: "client", jwt_issuer_id: "surface:BASE_APP",
    )
    cookies[AuthenticationBase::ACCESS_COOKIE_KEY] = access_token
    {
      "Authorization" => "Bearer #{access_token}",
      "Client-Agent" => "Mozilla/5.0",
      "Host" => host,
      "X-TEST-SESSION-PUBLIC-ID" => token.public_id,
    }
  end

  def com_headers_for(visitor, host:, scope: "settings_email")
    token = VisitorToken.create!(
      visitor: visitor,
      visitor_token_kind_id: VisitorTokenKind::BROWSER_WEB,
      visitor_token_status_id: VisitorTokenStatus::ACTIVE,
      discard_at: 1.day.from_now,
    )
    BaseSelectorBootstrapAuthority.call(surface: :com, principal: visitor)
    BaseSelectorAuthority.prepare(surface: :com, principal: visitor, session: token)
    _verification, raw_verification = VisitorVerification.issue_for_token!(token: token)
    cookies[VisitorVerification.cookie_name] = raw_verification
    token.update!(
      last_step_up_at: Time.current,
      last_step_up_scope: scope,
      last_step_up_aal: "aal2",
      last_step_up_method: "passkey",
      last_step_up_session_public_id: token.public_id,
      last_step_up_purpose: "step_up",
      last_step_up_audience: "step_up:com",
    )
    access_token = AuthenticationToken.encode(
      visitor, host: host, session_public_id: token.public_id,
               resource_type: "visitor", jwt_issuer_id: "surface:BASE_COM",
    )
    cookies[AuthenticationBase::ACCESS_COOKIE_KEY] = access_token
    {
      "Authorization" => "Bearer #{access_token}",
      "Client-Agent" => "Mozilla/5.0",
      "Host" => host,
      "X-TEST-SESSION-PUBLIC-ID" => token.public_id,
    }
  end

  def org_headers_for(operator, host:, scope: "settings_email")
    token = OperatorToken.create!(
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
      last_step_up_scope: scope,
      last_step_up_aal: "aal2",
      last_step_up_method: "passkey",
      last_step_up_session_public_id: token.public_id,
      last_step_up_purpose: "step_up",
      last_step_up_audience: "step_up:org",
    )
    access_token = AuthenticationToken.encode(
      operator, host: host, session_public_id: token.public_id,
                resource_type: "operator", jwt_issuer_id: "surface:BASE_ORG",
    )
    cookies[AuthenticationBase::ACCESS_COOKIE_KEY] = access_token
    {
      "Authorization" => "Bearer #{access_token}",
      "Client-Agent" => "Mozilla/5.0",
      "Host" => host,
      "X-TEST-SESSION-PUBLIC-ID" => token.public_id,
    }
  end
end
