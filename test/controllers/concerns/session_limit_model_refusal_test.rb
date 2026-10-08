# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

# The capacity gate counts active sessions while the token model also enforces a total ceiling.
# When the model refuses a login the gate allowed, nothing is issued: the login goes to the ordinary
# session-limit resolution, never to the retired immediate 403 refusal.
class SessionLimitModelRefusalTest < ActionDispatch::IntegrationTest
  fixtures :clients

  class TestController < ApplicationController
    include AuthenticationClient
    include SessionLimitGate

    declare_authentication_mode! :open

    def dbsc_route_helper(*_helpers)
      "/test/dbsc"
    end

    def create
      user = Client.find(params[:user_id])
      flow = ClientSignInFlow.find_by(id: params[:flow_id])
      result = log_in(user, establishment: :root_login, require_totp_check: false, sign_in_flow: flow)

      render json: { status: result.fetch(:status).to_s }, status: :ok
    end
  end

  setup do
    @original_login_cooldown = login_cooldown
    self.login_cooldown = 0.seconds
    @user = clients(:one)
    ClientToken.where(user_id: @user.id).delete_all
    Prosopite.pause do
      # Below the active limit, but at the model's total-session ceiling because of leftover
      # restricted rows from the retired session-limit placeholder. The token model's own
      # validation is the last line, so the attempt is refused instead of over-issuing.
      token = ClientToken.create!(user: @user, user_token_status_id: ClientTokenStatus::ACTIVE)
      token.rotate_refresh_token!
      2.times do
        restricted = ClientToken.create!(user: @user, user_token_status_id: ClientTokenStatus::RESTRICTED)
        restricted.rotate_refresh_token!(discard_at: 15.minutes.from_now)
      end
    end

    Rails.application.routes.draw do
      post "/test/model_refusal_login" => "session_limit_model_refusal_test/test#create"
    end
  end

  teardown do
    self.login_cooldown = @original_login_cooldown
    Rails.application.reload_routes!
  end

  test "a login the token model refuses goes to session-limit resolution and issues nothing" do
    flow = ClientSignInFlow.create!(
      principal_id: @user.id,
      state_id: ClientSignInFlow.state_id_for("SESSION_ISSUANCE_PENDING"),
      nonce_digest: ClientSignInFlow.digest_nonce(SecureRandom.hex(8)),
    )
    before_count = ClientToken.where(user_id: @user.id).count

    assert_difference(-> { ClientSessionLimitResolutionTransaction.open.where(sign_in_flow_id: flow.id).count }, 1) do
      post "/test/model_refusal_login", params: { user_id: @user.id, flow_id: flow.id }, as: :json
    end

    assert_response :ok
    assert_equal "session_limit_pending", response.parsed_body.fetch("status")
    assert_equal before_count, ClientToken.where(user_id: @user.id).count
    assert_equal "SESSION_ISSUANCE_PENDING", flow.reload.state_name_for(flow.state_id)
  end

  test "a refused login without a sign-in flow has no resolution parent and issues nothing" do
    before_count = ClientToken.where(user_id: @user.id).count

    post "/test/model_refusal_login", params: { user_id: @user.id }, as: :json

    assert_response :ok
    assert_equal "invalid_request", response.parsed_body.fetch("status")
    assert_equal before_count, ClientToken.where(user_id: @user.id).count
  end

  test "a revoked device session is excluded from the active capacity count" do
    ClientToken.where(user_id: @user.id).delete_all
    tokens =
      Array.new(ClientToken::MAX_SESSIONS_PER_USER) do
        ClientToken.create!(user: @user, user_token_status_id: ClientTokenStatus::ACTIVE)
      end
    tokens.first.device_session.revoke!(reason: "capacity-test")

    post "/test/model_refusal_login", params: { user_id: @user.id }, as: :json

    assert_response :ok
    assert_equal "success", response.parsed_body.fetch("status")
    assert_equal ClientToken::MAX_SESSIONS_PER_USER + 1, ClientToken.where(user_id: @user.id).count
    assert_equal ClientToken::MAX_SESSIONS_PER_USER, ClientToken.where(user_id: @user.id).joins(:device_session)
      .where(client_device_sessions: { status_id: ClientDeviceSession::STATUS_ACTIVE, revoked_at: nil })
      .count
  end
end
