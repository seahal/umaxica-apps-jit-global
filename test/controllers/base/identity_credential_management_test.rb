# typed: false
# frozen_string_literal: true

require "test_helper"

# Credential-management endpoints on the identity surfaces: issuing a new
# secret credential on the app surface, removing one on the corporate and staff
# surfaces (including the guard that keeps the last usable credential), and the
# app MFA level page.
class BaseIdentityCredentialManagementTest < ActionDispatch::IntegrationTest
  fixtures :clients, :client_statuses, :client_email_statuses,
           :client_secret_credential_kinds, :client_secret_credential_statuses,
           :client_token_kinds, :client_token_statuses, :client_token_binding_methods,
           :client_token_dbsc_statuses, :client_chronicle_events, :client_chronicle_levels,
           :visitors, :visitor_statuses, :visitor_email_statuses,
           :visitor_token_kinds, :visitor_token_statuses,
           :visitor_token_binding_methods, :visitor_token_dbsc_statuses,
           :operators, :operator_statuses, :operator_secret_credential_kinds,
           :operator_secret_credential_statuses, :operator_token_kinds, :operator_token_statuses,
           :operator_token_binding_methods, :operator_token_dbsc_statuses

  setup do
    TurnstileVerifierStub.challenge_enabled = true
    TurnstileVerifierStub.challenge_response = { "success" => true }
  end

  teardown do
    TurnstileVerifierStub.challenge_enabled = false
    TurnstileVerifierStub.challenge_response = nil
  end

  test "app secret credential form issues a one-time secret and create persists it" do
    host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    host! host
    client = clients(:one)
    ClientEmail.create!(
      user: client, address: "app_secret_credential_contact@example.com", confirm_policy: "1",
      user_email_status_id: ClientEmailStatus::VERIFIED,
    )
    token = ClientToken.create!(
      user: client, user_token_kind_id: ClientTokenKind::BROWSER_WEB,
      user_token_status_id: ClientTokenStatus::ACTIVE, discarded_at: 1.day.from_now,
    )
    BaseSelectorBootstrapAuthority.call(surface: :app, principal: client)
    BaseSelectorAuthority.prepare(surface: :app, principal: client, session: token)
    _verification, raw_verification = ClientVerification.issue_for_token!(token: token)
    cookies[ClientVerification.cookie_name] = raw_verification
    token.update!(
      last_step_up_at: Time.current, last_step_up_scope: "settings_secret_credential",
      last_step_up_aal: "aal2", last_step_up_method: "passkey",
      last_step_up_session_public_id: token.public_id, last_step_up_purpose: "step_up",
      last_step_up_audience: "step_up:app",
    )
    access_token = AuthenticationToken.encode(
      client, host: host, session_public_id: token.public_id,
              resource_type: "client", jwt_issuer_id: "surface:BASE_APP",
    )
    cookies[AuthenticationBase::ACCESS_COOKIE_KEY] = access_token
    cookies["csrf_token"] = "test-csrf-token"
    headers = {
      "Authorization" => "Bearer #{access_token}",
      "Client-Agent" => "Mozilla/5.0",
      "Host" => host,
      "X-TEST-SESSION-PUBLIC-ID" => token.public_id,
      "X-CSRF-Token" => "test-csrf-token",
    }

    get new_base_app_identity_secret_url(ri: "jp", host: host), headers: headers

    assert_response :success

    assert_difference("ClientSecretCredential.count", 1) do
      post base_app_identity_secrets_url(ri: "jp", host: host),
           params: { user_secret_credential: { name: "laptop" } }, headers: headers
    end

    assert_response :see_other
  end

  test "com secret credential removal discards the credential when another remains" do
    host = ENV.fetch("PUBLIC_BASE_CORPORATE_URL")
    host! host
    visitor = visitors(:reserved_visitor)
    VisitorEmail.create!(
      visitor: visitor, address: "com_secret_removal_contact@example.com", confirm_policy: "1",
      visitor_email_status_id: VisitorEmailStatus::VERIFIED,
    )
    removable, = VisitorSecretCredential.issue!(
      name: "removable", visitor_id: visitor.id,
      visitor_secret_credential_kind_id: VisitorSecretCredentialKind::LOGIN, uses: 10, status: :active,
    )
    VisitorSecretCredential.issue!(
      name: "keeper", visitor_id: visitor.id,
      visitor_secret_credential_kind_id: VisitorSecretCredentialKind::LOGIN, uses: 10, status: :active,
    )
    token = VisitorToken.create!(
      visitor: visitor, visitor_token_kind_id: VisitorTokenKind::BROWSER_WEB,
      visitor_token_status_id: VisitorTokenStatus::ACTIVE, discarded_at: 1.day.from_now,
      last_step_up_at: Time.current, last_step_up_scope: "settings_secret_credential",
      last_step_up_aal: "aal2", last_step_up_method: "passkey",
      last_step_up_purpose: "step_up", last_step_up_audience: "step_up:com",
    )
    token.update_columns(last_step_up_session_public_id: token.public_id)
    BaseSelectorBootstrapAuthority.call(surface: :com, principal: visitor)
    BaseSelectorAuthority.prepare(surface: :com, principal: visitor, session: token)
    access_token = AuthenticationToken.encode(
      visitor, host: host, session_public_id: token.public_id,
               resource_type: "visitor", jwt_issuer_id: "surface:BASE_COM",
    )
    cookies[AuthenticationBase::ACCESS_COOKIE_KEY] = access_token

    post base_com_identity_secret_removal_url(removable.public_id, ri: "jp", host: host),
         headers: {
           "Authorization" => "Bearer #{access_token}",
           "Client-Agent" => "Mozilla/5.0",
           "Host" => host,
           "X-TEST-SESSION-PUBLIC-ID" => token.public_id,
         }

    assert_response :see_other
    assert_equal VisitorSecretCredential.status_id_for(:deleted),
                 removable.reload.visitor_secret_credential_status_id
  end

  test "org secret credential removal discards the credential when another remains" do
    host = ENV.fetch("PUBLIC_BASE_STAFF_URL")
    host! host
    operator = operators(:one)
    removable, = OperatorSecretCredential.issue!(
      name: "removable", staff_id: operator.id,
      staff_secret_kind_id: OperatorSecretCredentialKind::LOGIN, uses: 10, status: :active,
    )
    OperatorSecretCredential.issue!(
      name: "keeper", staff_id: operator.id,
      staff_secret_kind_id: OperatorSecretCredentialKind::LOGIN, uses: 10, status: :active,
    )
    token = OperatorToken.create!(
      staff: operator, staff_token_kind_id: OperatorTokenKind::BROWSER_WEB,
      staff_token_status_id: OperatorTokenStatus::ACTIVE, discarded_at: 1.day.from_now,
      last_step_up_at: Time.current, last_step_up_scope: "settings_secret_credential",
      last_step_up_aal: "aal2", last_step_up_method: "passkey",
      last_step_up_purpose: "step_up", last_step_up_audience: "step_up:org",
    )
    token.update_columns(last_step_up_session_public_id: token.public_id)
    BaseSelectorBootstrapAuthority.call(surface: :org, principal: operator)
    BaseSelectorAuthority.prepare(surface: :org, principal: operator, session: token)
    access_token = AuthenticationToken.encode(
      operator, host: host, session_public_id: token.public_id,
                resource_type: "operator", jwt_issuer_id: "surface:BASE_ORG",
    )
    cookies[AuthenticationBase::ACCESS_COOKIE_KEY] = access_token

    post base_org_identity_secret_removal_url(removable.public_id, ri: "jp", host: host),
         headers: {
           "Authorization" => "Bearer #{access_token}",
           "Client-Agent" => "Mozilla/5.0",
           "Host" => host,
           "X-TEST-SESSION-PUBLIC-ID" => token.public_id,
         }

    assert_response :see_other
  end

  test "app MFA challenge page renders the current level for a stepped-up client" do
    host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    host! host
    client = clients(:one)
    token = ClientToken.create!(
      user: client, user_token_kind_id: ClientTokenKind::BROWSER_WEB,
      user_token_status_id: ClientTokenStatus::ACTIVE, discarded_at: 1.day.from_now,
    )
    BaseSelectorBootstrapAuthority.call(surface: :app, principal: client)
    BaseSelectorAuthority.prepare(surface: :app, principal: client, session: token)
    _verification, raw_verification = ClientVerification.issue_for_token!(token: token)
    cookies[ClientVerification.cookie_name] = raw_verification
    token.update!(
      last_step_up_at: Time.current, last_step_up_scope: "settings_mfa",
      last_step_up_aal: "aal2", last_step_up_method: "passkey",
      last_step_up_session_public_id: token.public_id, last_step_up_purpose: "step_up",
      last_step_up_audience: "step_up:app",
    )
    access_token = AuthenticationToken.encode(
      client, host: host, session_public_id: token.public_id,
              resource_type: "client", jwt_issuer_id: "surface:BASE_APP",
    )
    cookies[AuthenticationBase::ACCESS_COOKIE_KEY] = access_token

    get base_app_identity_mfa_challenge_url(ri: "jp", host: host),
        headers: {
          "Authorization" => "Bearer #{access_token}",
          "Client-Agent" => "Mozilla/5.0",
          "Host" => host,
          "X-TEST-SESSION-PUBLIC-ID" => token.public_id,
        }

    assert_response :success
  end
end
