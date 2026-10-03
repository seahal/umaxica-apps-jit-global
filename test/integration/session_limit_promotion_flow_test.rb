# typed: false
# frozen_string_literal: true

require "test_helper"

class SessionLimitPromotionFlowTest < ActionDispatch::IntegrationTest
  fixtures :clients, :client_statuses, :client_email_statuses

  setup do
    @host = ENV.fetch("PUBLIC_AUTH_SERVICE_URL", "auth.app.localhost")
    ClientToken.where(user_id: clients(:one).id).delete_all
    host! @host
    TurnstileVerifierStub.challenge_enabled = true
    TurnstileVerifierStub.challenge_response = { "success" => true }
  end

  teardown do
    TurnstileVerifierStub.challenge_enabled = false
    TurnstileVerifierStub.challenge_response = nil
  end

  test "revoking one active session at the limit issues the new session and continues sign-in" do
    user = clients(:one)
    existing = Array.new(2) { ClientToken.create!(user: user, user_token_kind_id: ClientTokenKind::BROWSER_WEB) }
    email = user.client_emails.create!(address: "limit_#{SecureRandom.hex(4)}@example.com")
    post auth_app_sign_in_email_url(ri: "jp"),
         params: { :user_email => { address: email.address }, "cf-turnstile-response" => "t" }
    key = ROTP::Base32.random_base32
    email.store_otp(key, 7, 12.minutes.from_now.to_i)
    patch auth_app_sign_in_email_url(ri: "jp"),
          params: { "user_email" => { "pass_code" => ROTP::HOTP.new(key).at(7).to_s }, "cf-turnstile-response" => "t" }

    assert_redirected_to auth_app_sign_in_session_url(ri: "jp")
    follow_redirect!

    assert_equal "auth/app/sign/in/sessions/show", inertia_component
    items = inertia_props.fetch("active_sessions").fetch("items")

    assert_equal 2, items.size
    cycle = ClientSignInFlow.where(principal_id: user.id).recent_first.first

    assert_predicate cycle, :sign_in_session_limit_pending?

    patch auth_app_sign_in_session_url(ri: "jp"), params: { revoke_refs: [items.first.fetch("ref")] }

    assert_response :redirect
    assert_not_equal auth_app_sign_in_session_url(ri: "jp"), response.location
    revoked = existing.map(&:reload).count(&:revoked?)

    assert_equal 1, revoked
    cycle.reload

    assert_not cycle.sign_in_session_limit_pending?
    assert_predicate cycle.token_id, :present?
    assert_predicate cookies[AuthenticationBase::ACCESS_COOKIE_KEY].to_s, :present?
  end

  test "submitting the session limit form without a selection keeps the limit and explains why" do
    user = clients(:one)
    2.times { ClientToken.create!(user: user, user_token_kind_id: ClientTokenKind::BROWSER_WEB) }
    email = user.client_emails.create!(address: "limit_#{SecureRandom.hex(4)}@example.com")
    post auth_app_sign_in_email_url(ri: "jp"),
         params: { :user_email => { address: email.address }, "cf-turnstile-response" => "t" }
    key = ROTP::Base32.random_base32
    email.store_otp(key, 7, 12.minutes.from_now.to_i)
    patch auth_app_sign_in_email_url(ri: "jp"),
          params: { "user_email" => { "pass_code" => ROTP::HOTP.new(key).at(7).to_s }, "cf-turnstile-response" => "t" }

    patch auth_app_sign_in_session_url(ri: "jp"), params: { revoke_refs: [""] }

    assert_response :unprocessable_content
    assert_equal I18n.t("sign.app.in.session.no_sessions_selected"), inertia_props.fetch("alert")
    assert_predicate ClientSignInFlow.where(principal_id: user.id).recent_first.first, :sign_in_session_limit_pending?
  end

  test "cancelling at the session limit fails the sign-in without issuing a session" do
    user = clients(:one)
    existing = Array.new(2) { ClientToken.create!(user: user, user_token_kind_id: ClientTokenKind::BROWSER_WEB) }
    email = user.client_emails.create!(address: "limit_#{SecureRandom.hex(4)}@example.com")
    post auth_app_sign_in_email_url(ri: "jp"),
         params: { :user_email => { address: email.address }, "cf-turnstile-response" => "t" }
    key = ROTP::Base32.random_base32
    email.store_otp(key, 7, 12.minutes.from_now.to_i)
    patch auth_app_sign_in_email_url(ri: "jp"),
          params: { "user_email" => { "pass_code" => ROTP::HOTP.new(key).at(7).to_s }, "cf-turnstile-response" => "t" }
    cycle = ClientSignInFlow.where(principal_id: user.id).recent_first.first

    delete auth_app_sign_in_session_url(ri: "jp")

    assert_response :redirect
    assert_predicate cycle.reload, :sign_in_failed?
    assert(existing.map(&:reload).none?(&:revoked?))
    assert_predicate cookies[AuthenticationBase::ACCESS_COOKIE_KEY].to_s, :empty?
  end
end
