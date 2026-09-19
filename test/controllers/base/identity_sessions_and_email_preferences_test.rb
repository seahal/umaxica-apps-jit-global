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
      visitor_token_status_id: VisitorTokenStatus::ACTIVE, discarded_at: 1.day.from_now,
    )
    other_session = VisitorToken.create!(
      visitor: visitor, visitor_token_kind_id: VisitorTokenKind::BROWSER_WEB,
      visitor_token_status_id: VisitorTokenStatus::ACTIVE, discarded_at: 1.day.from_now,
    )
    BaseSelectorBootstrapAuthority.call(surface: :com, principal: visitor)
    BaseSelectorAuthority.prepare(surface: :com, principal: visitor, session: token)
    access_token = AuthenticationToken.encode(
      visitor, host: host, session_public_id: token.public_id,
               resource_type: "visitor", jwt_issuer_id: "surface:BASE_COM",
    )
    cookies[AuthenticationBase::ACCESS_COOKIE_KEY] = access_token

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
      visitor_token_status_id: VisitorTokenStatus::ACTIVE, discarded_at: 1.day.from_now,
    )
    other_session = VisitorToken.create!(
      visitor: visitor, visitor_token_kind_id: VisitorTokenKind::BROWSER_WEB,
      visitor_token_status_id: VisitorTokenStatus::ACTIVE, discarded_at: 1.day.from_now,
    )
    BaseSelectorBootstrapAuthority.call(surface: :com, principal: visitor)
    BaseSelectorAuthority.prepare(surface: :com, principal: visitor, session: token)
    access_token = AuthenticationToken.encode(
      visitor, host: host, session_public_id: token.public_id,
               resource_type: "visitor", jwt_issuer_id: "surface:BASE_COM",
    )
    cookies[AuthenticationBase::ACCESS_COOKIE_KEY] = access_token

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
      user_token_status_id: ClientTokenStatus::ACTIVE, discarded_at: 1.day.from_now,
      last_step_up_at: Time.current, last_step_up_scope: "settings_email",
      last_step_up_aal: "aal2", last_step_up_method: "passkey",
      last_step_up_purpose: "step_up", last_step_up_audience: "step_up:app",
    )
    token.update_columns(last_step_up_session_public_id: token.public_id)
    BaseSelectorBootstrapAuthority.call(surface: :app, principal: client)
    BaseSelectorAuthority.prepare(surface: :app, principal: client, session: token)
    access_token = AuthenticationToken.encode(
      client, host: host, session_public_id: token.public_id,
              resource_type: "client", jwt_issuer_id: "surface:BASE_APP",
    )
    cookies[AuthenticationBase::ACCESS_COOKIE_KEY] = access_token

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
      user_token_status_id: ClientTokenStatus::ACTIVE, discarded_at: 1.day.from_now,
      last_step_up_at: Time.current, last_step_up_scope: "settings_email",
      last_step_up_aal: "aal2", last_step_up_method: "passkey",
      last_step_up_purpose: "step_up", last_step_up_audience: "step_up:app",
    )
    token.update_columns(last_step_up_session_public_id: token.public_id)
    BaseSelectorBootstrapAuthority.call(surface: :app, principal: client)
    BaseSelectorAuthority.prepare(surface: :app, principal: client, session: token)
    access_token = AuthenticationToken.encode(
      client, host: host, session_public_id: token.public_id,
              resource_type: "client", jwt_issuer_id: "surface:BASE_APP",
    )
    cookies[AuthenticationBase::ACCESS_COOKIE_KEY] = access_token
    TurnstileVerifierStub.challenge_response = { "success" => false }

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
