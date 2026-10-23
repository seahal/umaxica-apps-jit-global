# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

# The capacity gate counts active sessions while the token model also enforces a total ceiling.
# When the model refuses a login the gate allowed, nothing is issued: the login goes to the ordinary
# session-limit resolution, never to the retired immediate 403 refusal.
class SessionLimitModelRefusalTest < ActiveSupport::TestCase
  fixtures :clients

  setup do
    @original_login_cooldown = login_cooldown
    self.login_cooldown = 0.seconds
    @user = clients(:one)
    ClientToken.where(user_id: @user.id).delete_all
    Prosopite.pause do
      # Keep one active device below the admission limit while the ACTIVE token-row ceiling is
      # full. Historical status-103 rows are preserved but do not consume either boundary.
      tokens =
        Array.new(ClientToken::MAX_TOTAL_SESSIONS_PER_USER) do
          ClientToken.create!(authentication_epoch: 0, user: @user, user_token_status_id: ClientTokenStatus::ACTIVE)
        end
      tokens.first(ClientToken::MAX_TOTAL_SESSIONS_PER_USER - (ClientToken::MAX_SESSIONS_PER_USER - 1)).each do |token|
        token.device_session.revoke!(reason: "capacity-test")
      end
    end

    @controller = Base::App::AuthorityController.new
    request = ActionDispatch::TestRequest.create
    request.host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    request.set_header("HTTPS", "on")
    request.session = ActionController::TestSession.new
    @controller.request = request
    @controller.response = ActionDispatch::TestResponse.new
  end

  teardown do
    self.login_cooldown = @original_login_cooldown
  end

  test "a login the token model refuses goes to session-limit resolution and issues nothing" do
    flow = ClientSignInFlow.create!(
      principal_id: @user.id,
      state_id: ClientSignInFlow.state_id_for("SESSION_ISSUANCE_PENDING"),
      nonce_digest: ClientSignInFlow.digest_nonce(SecureRandom.hex(8)),
    )
    before_count = ClientToken.where(user_id: @user.id).count

    result = nil
    assert_difference(-> { ClientSessionLimitResolutionTransaction.open.where(sign_in_flow_id: flow.id).count }, 1) do
      result = @controller.log_in(
        @user, establishment: :root_login, require_totp_check: false, sign_in_flow: flow,
      )
    end

    assert_equal :session_limit_pending, result.fetch(:status)
    assert_equal before_count, ClientToken.where(user_id: @user.id).count
    assert_equal "SESSION_ISSUANCE_PENDING", flow.reload.state_name_for(flow.state_id)
  end

  test "a refused login without a sign-in flow has no resolution parent and issues nothing" do
    before_count = ClientToken.where(user_id: @user.id).count

    result = @controller.log_in(@user, establishment: :root_login, require_totp_check: false)

    assert_equal :invalid_request, result.fetch(:status)
    assert_equal before_count, ClientToken.where(user_id: @user.id).count
  end

  test "a revoked device session is excluded from the active capacity count" do
    ClientToken.where(user_id: @user.id).delete_all
    tokens =
      Array.new(ClientToken::MAX_SESSIONS_PER_USER) do
        ClientToken.create!(authentication_epoch: 0, user: @user, user_token_status_id: ClientTokenStatus::ACTIVE)
      end
    tokens.first.device_session.revoke!(reason: "capacity-test")

    result = @controller.log_in(@user, establishment: :root_login, require_totp_check: false)

    assert_equal :success, result.fetch(:status)
    assert_equal ClientToken::MAX_SESSIONS_PER_USER + 1, ClientToken.where(user_id: @user.id).count
    assert_equal ClientToken::MAX_SESSIONS_PER_USER, ClientToken.where(user_id: @user.id).joins(:device_session)
      .where(client_device_sessions: { status_id: ClientDeviceSession::STATUS_ACTIVE, revoked_at: nil })
      .count
  end
end
