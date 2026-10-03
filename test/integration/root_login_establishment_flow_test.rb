# typed: false
# frozen_string_literal: true

require "test_helper"

# Public HTTP entry (Auth app email sign-in) through the real middleware and databases. Each case
# checks what the database, the cookies, the next request, and the audit say -- not only the
# response code (adr/root-login-establishment-boundary.md).
class RootLoginEstablishmentFlowTest < ActionDispatch::IntegrationTest
  fixtures :clients, :client_statuses, :client_email_statuses

  setup do
    host! ENV.fetch("PUBLIC_AUTH_SERVICE_URL", "auth.app.localhost")
    TurnstileVerifierStub.challenge_enabled = true
    TurnstileVerifierStub.challenge_response = { "success" => true }
    @user = clients(:one)
    ClientToken.where(user_id: @user.id).delete_all
    @email = @user.client_emails.create!(address: "root_#{SecureRandom.hex(4)}@example.com")
  end

  teardown do
    TurnstileVerifierStub.challenge_enabled = false
    TurnstileVerifierStub.challenge_response = nil
  end

  test "a normal sign-in establishes exactly one root login with its anchor, cookie, and audit" do
    assert_difference(-> { logged_in_audits }, 1) do
      assert_difference(-> { ClientToken.where(user_id: @user.id).count }, 1) do
        sign_in_with_email_otp!
        follow_redirect! while response.redirect? && same_host?(response.location)
      end
    end

    token = ClientToken.find_by!(user_id: @user.id)

    assert_predicate token, :active_status?
    assert_not_nil token.root_login_established_at
    assert_not_nil token.device_session_id
    assert_predicate cookies[AuthenticationBase::ACCESS_COOKIE_KEY].to_s, :present?
    assert_equal 1, ClientSignInFlow.where(principal_id: @user.id, token_id: token.id).count
  end

  test "at the session limit nothing is issued: no token, no cookie, no audit, and the flow waits" do
    existing = Array.new(ClientToken::MAX_SESSIONS_PER_USER) { ClientToken.create!(user: @user) }

    assert_no_difference(-> { logged_in_audits }) do
      assert_no_difference(-> { ClientToken.where(user_id: @user.id).count }) do
        sign_in_with_email_otp!
      end
    end

    assert_equal "/sign/in/session", URI.parse(response.location).path
    assert_predicate cookies[AuthenticationBase::ACCESS_COOKIE_KEY].to_s, :blank?
    assert_predicate cookies[AuthenticationBase::REFRESH_COOKIE_KEY].to_s, :blank?
    assert_predicate latest_flow, :sign_in_session_limit_pending?
    assert_nil latest_flow.token_id
    assert(existing.all? { |token| token.reload.active_status? })
    assert_equal 0, ClientToken.where(user_id: @user.id, user_token_status_id: ClientTokenStatus::RESTRICTED).count
  end

  test "resolving the limit commits the waiting flow once; a repeated submit issues nothing more" do
    existing = Array.new(ClientToken::MAX_SESSIONS_PER_USER) { ClientToken.create!(user: @user) }
    sign_in_with_email_otp!
    follow_redirect!
    ref = inertia_props.fetch("active_sessions").fetch("items").first.fetch("ref")

    assert_difference(-> { ClientToken.where(user_id: @user.id).count }, 1) do
      patch auth_app_sign_in_session_url(ri: "jp"), params: { revoke_refs: [ref] }
    end

    issued = ClientToken.where(user_id: @user.id).order(:id).last

    assert_equal 1, existing.map(&:reload).count(&:revoked?)
    assert_equal issued.id, latest_flow.token_id
    assert_not_nil issued.root_login_established_at
    assert_predicate cookies[AuthenticationBase::ACCESS_COOKIE_KEY].to_s, :present?

    assert_no_difference(-> { ClientToken.where(user_id: @user.id).count }) do
      patch auth_app_sign_in_session_url(ri: "jp"), params: { revoke_refs: [ref] }
    end
  end

  test "cancelling at the limit ends only the waiting flow and keeps every existing session" do
    existing = Array.new(ClientToken::MAX_SESSIONS_PER_USER) { ClientToken.create!(user: @user) }
    sign_in_with_email_otp!
    flow = latest_flow

    delete auth_app_sign_in_session_url(ri: "jp")

    assert_response :see_other
    assert_predicate flow.reload, :sign_in_failed?
    assert(existing.all? { |token| token.reload.active_status? })

    get auth_app_sign_in_session_url(ri: "jp")

    assert_response :redirect
    assert_not_equal "/sign/in/session", URI.parse(response.location).path
  end

  test "a principal id in the session alone does not open session-limit management" do
    Array.new(ClientToken::MAX_SESSIONS_PER_USER) { ClientToken.create!(user: @user) }

    get auth_app_sign_in_session_url(ri: "jp")

    assert_response :redirect
    assert_not_equal "/sign/in/session", URI.parse(response.location).path
  end

  test "sign-out inside the cooldown does not exempt the next root login; repeated refusals do not move the anchor" do
    freeze_time do
      sign_in_with_email_otp!
      first = ClientToken.find_by!(user_id: @user.id)
      AuthenticationLogoutCurrentSession.call(resource: @user, token: first, reason: "user_logout")
      cookies.delete(AuthenticationBase::ACCESS_COOKIE_KEY)
      cookies.delete(AuthenticationBase::REFRESH_COOKIE_KEY)

      travel 10.seconds
      assert_no_difference(-> { ClientToken.where(user_id: @user.id).count }) do
        sign_in_with_email_otp!(another_email)
      end

      assert_response :too_many_requests
      # Full window, never the time remaining: the response must not reveal when the account
      # last signed in.
      assert_equal "30", response.headers["Retry-After"]
      assert_equal "no-store", response.headers["Cache-Control"]
      assert_includes response.body, "/sign"

      travel 5.seconds
      sign_in_with_email_otp!(another_email)

      assert_response :too_many_requests
      assert_equal "30", response.headers["Retry-After"]
      assert_equal first.root_login_established_at,
                   ClientToken.where(user_id: @user.id).maximum(:root_login_established_at)

      travel 15.seconds
      assert_difference(-> { ClientToken.where(user_id: @user.id).count }, 1) do
        sign_in_with_email_otp!(another_email)
      end
    end
  end

  test "a legacy RESTRICTED token does not authenticate even with a valid access token" do
    legacy = ClientToken.create!(user: @user, user_token_status_id: ClientTokenStatus::RESTRICTED)
    host! ENV.fetch("PUBLIC_BASE_SERVICE_URL")

    get base_app_root_url(ri: "jp"),
        headers: as_user_headers(@user, host: ENV.fetch("PUBLIC_BASE_SERVICE_URL"), session_public_id: legacy.public_id)

    assert_not_equal 200, response.status
  end

  private

  # Each attempt may use its own address of the same account, so the OTP resend throttle of one
  # address does not stand in for the decision under test.
  def sign_in_with_email_otp!(email = @email)
    post(
      auth_app_sign_in_email_url(ri: "jp"),
      params: { :user_email => { address: email.address }, "cf-turnstile-response" => "t" },
    )
    key = ROTP::Base32.random_base32
    email.reload.store_otp(key, 7, 12.minutes.from_now.to_i)
    patch(
      auth_app_sign_in_email_url(ri: "jp"),
      params: { "user_email" => { "pass_code" => ROTP::HOTP.new(key).at(7).to_s },
                "cf-turnstile-response" => "t", },
    )
  end

  def another_email
    @user.client_emails.create!(address: "root_#{SecureRandom.hex(4)}@example.com")
  end

  def latest_flow
    ClientSignInFlow.where(principal_id: @user.id).recent_first.first
  end

  def logged_in_audits
    ClientChronicle.where(subject_id: @user.id, event_id: ClientChronicleEvent::LOGGED_IN).count
  end

  def same_host?(location)
    URI.parse(location).host.in?([nil, host])
  end
end
