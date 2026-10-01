# typed: false
# frozen_string_literal: true

require "test_helper"

class Auth::App::Sign::In::ChecksAuthorizationTest < ActionController::TestCase
  tests Auth::App::Sign::In::ChecksController

  setup do
    @host = ENV.fetch("PUBLIC_AUTH_SERVICE_URL", "auth.app.localhost")
    @user = Client.create!(status_id: ClientStatus::ACTIVE, visibility_id: ClientVisibility::USER)
    @token = ClientToken.create!(user: @user, user_token_kind_id: ClientTokenKind::BROWSER_WEB)
    nonce = "checkpoint-policy-controller-test-nonce"
    @cycle = ClientSignInFlow.create!(
      principal_id: @user.id,
      token: @token,
      status_id: ClientSignInFlow.status_id_for("CHECKPOINT_PENDING"),
      step: "checkpoint",
      return_to: "/after",
      nonce_digest: ClientSignInFlow.digest_nonce(nonce),
      issued_at: Time.current,
      expires_at: 15.minutes.from_now,
    )
    SignInCycleLocator.new(@request.session, surface: :app, actor: @user, token: @token).issue!(@cycle, nonce: nonce)
    @request.host = @host
    @request.headers["X-TEST-CURRENT-USER"] = @user.id.to_s
    @request.headers["X-TEST-SESSION-PUBLIC-ID"] = @token.public_id
    @request.headers["Authorization"] = "Bearer #{access_token}"
  end

  test "checkpoint sequence authorizes before the private action completes" do
    get :show, params: { ri: "jp" }

    assert_response :redirect
    assert_not_equal 500, response.status
  end

  private

  def access_token
    AuthenticationToken.encode(
      @user,
      host: @host,
      session_public_id: @token.public_id,
      resource_type: "client",
      jwt_issuer_id: "surface:AUTH_APP",
    )
  end
end
