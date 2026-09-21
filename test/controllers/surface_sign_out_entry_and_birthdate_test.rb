# typed: false
# frozen_string_literal: true

require "test_helper"

# Two per-surface endpoints that repeat across the auth and core surfaces: the
# sign-out entry redirect and its confirmation page, plus the step-up-gated
# birthdate page on the corporate and staff identity surfaces.
class SurfaceSignOutEntryAndBirthdateTest < ActionDispatch::IntegrationTest
  fixtures :visitors, :visitor_statuses, :visitor_token_kinds, :visitor_token_statuses,
           :visitor_token_binding_methods, :visitor_token_dbsc_statuses,
           :operators, :operator_statuses, :operator_token_kinds, :operator_token_statuses,
           :operator_token_binding_methods, :operator_token_dbsc_statuses

  test "auth com sign-out entry redirects to the confirmation page" do
    host = ENV.fetch("PUBLIC_AUTH_CORPORATE_URL")
    host! host

    get new_auth_com_sign_out_url(ri: "jp", host: host), headers: { "Host" => host }

    assert_response :see_other
    assert_redirected_to edit_auth_com_sign_out_path(ri: "jp")
  end

  test "core com sign-out confirmation page renders for an anonymous visitor" do
    host = ENV.fetch("PUBLIC_CORE_CORPORATE_URL")
    host! host

    get edit_core_com_sign_out_url(ri: "jp", host: host), headers: { "Host" => host }

    assert_response :success
  end

  test "core org sign-out confirmation page renders for an anonymous operator" do
    host = ENV.fetch("PUBLIC_CORE_STAFF_URL")
    host! host

    get edit_core_org_sign_out_url(ri: "jp", host: host), headers: { "Host" => host }

    assert_response :success
  end

  test "com birthdate page shows the visitor's stored birthdate behind a fresh step-up" do
    host = ENV.fetch("PUBLIC_BASE_CORPORATE_URL")
    host! host
    visitor = visitors(:reserved_visitor)
    visitor.update!(birthdate: "1990-01-02")
    token = VisitorToken.create!(
      visitor: visitor, visitor_token_kind_id: VisitorTokenKind::BROWSER_WEB,
      visitor_token_status_id: VisitorTokenStatus::ACTIVE, discard_at: 1.day.from_now,
    )
    BaseSelectorBootstrapAuthority.call(surface: :com, principal: visitor)
    BaseSelectorAuthority.prepare(surface: :com, principal: visitor, session: token)
    _verification, raw_verification = VisitorVerification.issue_for_token!(token: token)
    cookies[VisitorVerification.cookie_name] = raw_verification
    token.update!(
      last_step_up_at: Time.current, last_step_up_scope: "settings_birthdate",
      last_step_up_aal: "aal2", last_step_up_method: "passkey",
      last_step_up_session_public_id: token.public_id, last_step_up_purpose: "step_up",
      last_step_up_audience: "step_up:com",
    )
    access_token = AuthenticationToken.encode(
      visitor, host: host, session_public_id: token.public_id,
               resource_type: "visitor", jwt_issuer_id: "surface:BASE_COM",
    )
    cookies[AuthenticationBase::ACCESS_COOKIE_KEY] = access_token

    get base_com_identity_birthdate_url(ri: "jp", host: host),
        headers: {
          "Authorization" => "Bearer #{access_token}",
          "Client-Agent" => "Mozilla/5.0",
          "Host" => host,
          "X-TEST-SESSION-PUBLIC-ID" => token.public_id,
        }

    assert_response :success
    assert_equal I18n.t("sign.com.settings.birthdate.show.page_title"), inertia_props.fetch("title")
  end

  test "org birthdate page shows the operator's stored birthdate behind a fresh step-up" do
    host = ENV.fetch("PUBLIC_BASE_STAFF_URL")
    host! host
    operator = operators(:one)
    operator.update!(birthdate: "1985-03-04")
    token = OperatorToken.create!(
      staff: operator, staff_token_kind_id: OperatorTokenKind::BROWSER_WEB,
      staff_token_status_id: OperatorTokenStatus::ACTIVE, discard_at: 1.day.from_now,
    )
    BaseSelectorBootstrapAuthority.call(surface: :org, principal: operator)
    BaseSelectorAuthority.prepare(surface: :org, principal: operator, session: token)
    _verification, raw_verification = OperatorVerification.issue_for_token!(token: token)
    cookies[OperatorVerification.cookie_name] = raw_verification
    token.update!(
      last_step_up_at: Time.current, last_step_up_scope: "settings_birthdate",
      last_step_up_aal: "aal2", last_step_up_method: "passkey",
      last_step_up_session_public_id: token.public_id, last_step_up_purpose: "step_up",
      last_step_up_audience: "step_up:org",
    )
    access_token = AuthenticationToken.encode(
      operator, host: host, session_public_id: token.public_id,
                resource_type: "operator", jwt_issuer_id: "surface:BASE_ORG",
    )
    cookies[AuthenticationBase::ACCESS_COOKIE_KEY] = access_token

    get base_org_identity_birthdate_url(ri: "jp", host: host),
        headers: {
          "Authorization" => "Bearer #{access_token}",
          "Client-Agent" => "Mozilla/5.0",
          "Host" => host,
          "X-TEST-SESSION-PUBLIC-ID" => token.public_id,
        }

    assert_response :success
  end
end
