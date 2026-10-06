# typed: false
# frozen_string_literal: true

require "test_helper"

# A destructive action reached without a fresh step-up is refused, and the
# refusal has to be readable by whoever asked: a document request gets the
# plain-text notice, a JSON request gets the same message as a JSON error. The
# refusal never performs the action, on any surface.
class StepUpRequiredResponseShapeTest < ActionDispatch::IntegrationTest
  fixtures :clients, :client_statuses, :client_token_kinds, :client_token_statuses,
           :client_token_binding_methods, :client_token_dbsc_statuses,
           :operators, :operator_statuses, :operator_token_kinds, :operator_token_statuses,
           :operator_token_binding_methods, :operator_token_dbsc_statuses

  test "an app document request without step-up is refused in plain text" do
    host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    host! host
    client = clients(:one)
    token = ClientToken.create!(
      user: client, user_token_kind_id: ClientTokenKind::BROWSER_WEB,
      user_token_status_id: ClientTokenStatus::ACTIVE, discard_at: 1.day.from_now,
    )
    token.update!(root_login_established_at: ClientToken.database_now, established_authentication_method: "passkey")
    BaseSelectorBootstrapAuthority.call(surface: :app, principal: client)
    BaseSelectorAuthority.prepare(surface: :app, principal: client, session: token)
    install_base_browser_rp_credentials!(surface: "app", host: host, actor: client, token: token)
    access_token = AuthenticationToken.encode(
      client, host: host, session_public_id: token.public_id,
              resource_type: "client", jwt_issuer_id: "surface:BASE_APP",
    )
    patch base_app_identity_withdrawal_url(ri: "jp", host: host),
          params: { ack_schedule_purge: "1" },
          headers: {
            "Authorization" => "Bearer #{access_token}",
            "Client-Agent" => "Mozilla/5.0",
            "Host" => host,
            "X-TEST-SESSION-PUBLIC-ID" => token.public_id,
          }

    assert_response :unauthorized
    assert_equal VerificationBase::STEP_UP_REQUIRED_MESSAGE, response.body
    assert_not ClientWithdrawalFlow.exists?(client_id: client.id)
  end

  test "an app JSON request without step-up is refused as a JSON error" do
    host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    host! host
    client = clients(:one)
    token = ClientToken.create!(
      user: client, user_token_kind_id: ClientTokenKind::BROWSER_WEB,
      user_token_status_id: ClientTokenStatus::ACTIVE, discard_at: 1.day.from_now,
    )
    token.update!(root_login_established_at: ClientToken.database_now, established_authentication_method: "passkey")
    BaseSelectorBootstrapAuthority.call(surface: :app, principal: client)
    BaseSelectorAuthority.prepare(surface: :app, principal: client, session: token)
    install_base_browser_rp_credentials!(surface: "app", host: host, actor: client, token: token)
    access_token = AuthenticationToken.encode(
      client, host: host, session_public_id: token.public_id,
              resource_type: "client", jwt_issuer_id: "surface:BASE_APP",
    )
    patch base_app_identity_withdrawal_url(ri: "jp", host: host),
          params: { ack_schedule_purge: "1" }, as: :json,
          headers: {
            "Authorization" => "Bearer #{access_token}",
            "Client-Agent" => "Mozilla/5.0",
            "Host" => host,
            "Accept" => "application/json",
            "X-TEST-SESSION-PUBLIC-ID" => token.public_id,
          }

    assert_response :unauthorized
    assert_equal VerificationBase::STEP_UP_REQUIRED_MESSAGE, response.parsed_body.fetch("error")
    assert_not ClientWithdrawalFlow.exists?(client_id: client.id)
  end

  test "an org document request without step-up is refused in plain text" do
    host = ENV.fetch("PUBLIC_BASE_STAFF_URL")
    host! host
    operator = operators(:one)
    token = OperatorToken.create!(
      staff: operator, staff_token_kind_id: OperatorTokenKind::BROWSER_WEB,
      staff_token_status_id: OperatorTokenStatus::ACTIVE, discard_at: 1.day.from_now,
    )
    token.update!(root_login_established_at: OperatorToken.database_now, established_authentication_method: "passkey")
    BaseSelectorBootstrapAuthority.call(surface: :org, principal: operator)
    BaseSelectorAuthority.prepare(surface: :org, principal: operator, session: token)
    install_base_browser_rp_credentials!(surface: "org", host: host, actor: operator, token: token)
    access_token = AuthenticationToken.encode(
      operator, host: host, session_public_id: token.public_id,
                resource_type: "operator", jwt_issuer_id: "surface:BASE_ORG",
    )
    post base_org_identity_emails_registration_url(ri: "jp", host: host),
         params: { staff_email: { raw_address: "org_step_up_required@example.com" } },
         headers: {
           "Authorization" => "Bearer #{access_token}",
           "Client-Agent" => "Mozilla/5.0",
           "Host" => host,
           "X-TEST-SESSION-PUBLIC-ID" => token.public_id,
         }

    assert_response :unauthorized
    assert_equal VerificationBase::STEP_UP_REQUIRED_MESSAGE, response.body
    assert_not OperatorEmail.exists?(address: "org_step_up_required@example.com")
  end

  test "an org JSON request without step-up is refused as a JSON error" do
    host = ENV.fetch("PUBLIC_BASE_STAFF_URL")
    host! host
    operator = operators(:one)
    token = OperatorToken.create!(
      staff: operator, staff_token_kind_id: OperatorTokenKind::BROWSER_WEB,
      staff_token_status_id: OperatorTokenStatus::ACTIVE, discard_at: 1.day.from_now,
    )
    token.update!(root_login_established_at: OperatorToken.database_now, established_authentication_method: "passkey")
    BaseSelectorBootstrapAuthority.call(surface: :org, principal: operator)
    BaseSelectorAuthority.prepare(surface: :org, principal: operator, session: token)
    install_base_browser_rp_credentials!(surface: "org", host: host, actor: operator, token: token)
    access_token = AuthenticationToken.encode(
      operator, host: host, session_public_id: token.public_id,
                resource_type: "operator", jwt_issuer_id: "surface:BASE_ORG",
    )
    post base_org_identity_emails_registration_url(ri: "jp", host: host),
         params: { staff_email: { raw_address: "org_step_up_required_json@example.com" } }, as: :json,
         headers: {
           "Authorization" => "Bearer #{access_token}",
           "Client-Agent" => "Mozilla/5.0",
           "Host" => host,
           "Accept" => "application/json",
           "X-TEST-SESSION-PUBLIC-ID" => token.public_id,
         }

    assert_response :unauthorized
    assert_equal VerificationBase::STEP_UP_REQUIRED_MESSAGE, response.parsed_body.fetch("error")
  end
  test "an org JSON request from an Emergency Access session is refused with 403 instead of a step-up prompt" do
    host = ENV.fetch("PUBLIC_BASE_STAFF_URL")
    host! host
    operator = operators(:one)
    token = OperatorToken.create!(
      staff: operator, staff_token_kind_id: OperatorTokenKind::BROWSER_WEB,
      staff_token_status_id: OperatorTokenStatus::ACTIVE, discard_at: 1.day.from_now,
      authentication_context: AuthenticationContextValue::EMERGENCY_KEY,
    )
    token.update!(root_login_established_at: OperatorToken.database_now, established_authentication_method: "passkey")
    BaseSelectorBootstrapAuthority.call(surface: :org, principal: operator)
    BaseSelectorAuthority.prepare(surface: :org, principal: operator, session: token)
    install_base_browser_rp_credentials!(surface: "org", host: host, actor: operator, token: token)
    access_token = AuthenticationToken.encode(
      operator, host: host, session_public_id: token.public_id,
                resource_type: "operator", jwt_issuer_id: "surface:BASE_ORG",
    )
    assert_no_difference("OperatorEmail.count") do
      post base_org_identity_emails_registration_url(ri: "jp", host: host),
           params: { staff_email: { raw_address: "org_step_up_emergency_json@example.com" } }, as: :json,
           headers: {
             "Authorization" => "Bearer #{access_token}",
             "Client-Agent" => "Mozilla/5.0",
             "Host" => host,
             "Accept" => "application/json",
             "X-TEST-SESSION-PUBLIC-ID" => token.public_id,
           }
    end

    assert_response :forbidden
    assert_equal I18n.t("auth.step_up.emergency_unavailable"), response.parsed_body.fetch("error")
  end

  test "an app JSON request from a client with no step-up method asks to register one" do
    host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    host! host
    client = Client.create!(status_id: ClientStatus::NOTHING, visibility_id: ClientVisibility::USER)
    token = ClientToken.create!(
      user: client, user_token_kind_id: ClientTokenKind::BROWSER_WEB,
      user_token_status_id: ClientTokenStatus::ACTIVE, discard_at: 1.day.from_now,
    )
    token.update!(root_login_established_at: ClientToken.database_now, established_authentication_method: "passkey")
    BaseSelectorBootstrapAuthority.call(surface: :app, principal: client)
    BaseSelectorAuthority.prepare(surface: :app, principal: client, session: token)
    install_base_browser_rp_credentials!(surface: "app", host: host, actor: client, token: token)
    access_token = AuthenticationToken.encode(
      client, host: host, session_public_id: token.public_id,
              resource_type: "client", jwt_issuer_id: "surface:BASE_APP",
    )
    patch base_app_identity_withdrawal_url(ri: "jp", host: host),
          params: { ack_schedule_purge: "1" }, as: :json,
          headers: {
            "Authorization" => "Bearer #{access_token}",
            "Client-Agent" => "Mozilla/5.0",
            "Host" => host,
            "Accept" => "application/json",
            "X-TEST-SESSION-PUBLIC-ID" => token.public_id,
          }

    assert_response :unprocessable_content
    assert_equal I18n.t("auth.step_up.register_methods_required"), response.parsed_body.fetch("error")
    assert_not ClientWithdrawalFlow.exists?(client_id: client.id)
  end
end
