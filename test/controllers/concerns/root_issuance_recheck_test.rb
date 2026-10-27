# typed: false
# frozen_string_literal: true

require "test_helper"

# D-163 / A44-1: a stop that commits while a login waits for the principal lock is seen under the
# lock. The login's actor object was loaded before the stop, so its early checks still pass; the
# decision made on the row reloaded under the lock must refuse, and no Root is created.
class RootIssuanceRecheckTest < ActiveSupport::TestCase
  fixtures :clients

  setup do
    @original_login_cooldown = login_cooldown
    self.login_cooldown = 0.seconds
    @user = clients(:one)
    ClientToken.where(user_id: @user.id).delete_all
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

  test "an administrative lock committed after the early checks refuses the Root under the lock" do
    loaded_before_stop = Client.find(@user.id)
    flow = issuance_flow
    Client.transaction do
      locked = Client.lock.find(@user.id)
      locked.update_columns(access_state: AdministrativeAccessLockable::ACCESS_STATE_ADMIN_LOCKED)
      IdentityAuthenticationStopRecorder.call(actor: locked, reason: "administrative_access_lock")
    end

    result = nil
    assert_no_difference(-> { ClientToken.where(user_id: @user.id).count }) do
      result = @controller.log_in(
        loaded_before_stop, establishment: :root_login, require_totp_check: false, sign_in_flow: flow,
      )
    end

    assert_equal :access_locked, result.fetch(:status)
  end

  test "without a stop the same login issues its Root carrying the current epoch" do
    flow = issuance_flow

    result = @controller.log_in(
      Client.find(@user.id), establishment: :root_login, require_totp_check: false, sign_in_flow: flow,
    )

    assert_equal :success, result.fetch(:status)
    assert_equal @user.reload.authentication_epoch, ClientToken.where(user_id: @user.id).sole.authentication_epoch
  end

  # A44-2: the stop commits after the Root insert. The Root carries the pre-stop epoch, so the OP
  # apply of the committed stop event revokes it, and the authoritative epoch check (D-165) refuses
  # it at every boundary even before that apply.
  test "A44-2: a later identity stop revokes and rejects the earlier Root" do
    result = @controller.log_in(
      Client.find(@user.id), establishment: :root_login, require_totp_check: false, sign_in_flow: issuance_flow,
    )

    assert_equal :success, result.fetch(:status)
    root = ClientToken.where(user_id: @user.id).sole
    client = OidcClientRegistry.find!("core-app-jp")
    grant = OpAppGrant.create!(
      authentication_epoch: root.authentication_epoch,
      client_token: root,
      oidc_client_id: client.client_id,
      oidc_scope: "openid",
      oidc_jti: SecureRandom.uuid,
      refresh_token_expires_at: 1.hour.from_now,
    )
    access_token = AuthenticationTokenService.encode(
      @user,
      host: OidcIssuer.host_for_resource_type("client"),
      resource_type: "client",
      session_public_id: root.public_id,
      base_session_public_id: root.public_id,
      oidc_sid: grant.public_id,
      oidc_jti: grant.oidc_jti,
      expires_at: 5.minutes.from_now,
      scopes: %w(openid),
      issuer: OidcIssuer.for_resource_type("client"),
      audiences: [client.aud],
      subject: OidcSubject.for(@user, resource_type: "client"),
      jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_resource_type("client"),
      client_id: client.client_id,
    )

    event =
      Client.transaction do
        IdentityAuthenticationStopRecorder.call(actor: Client.lock.find(@user.id), reason: "withdrawal_suspend")
      end

    assert_not AuthenticationEpochValue.root_current?(root_token: root.reload, actor: @user.reload)
    browser_result = AuthenticationCurrentResourceResolver.new(
      access_token: jwt_access_token_for(
        @user,
        host: ENV.fetch("PUBLIC_BASE_SERVICE_URL"),
        session_public_id: root.public_id,
        resource_type: "client",
      ),
      request_host: ENV.fetch("PUBLIC_BASE_SERVICE_URL"),
      resource_type: "client",
      resource_class: Client,
      token_class: ClientToken,
      jwt_issuer_id: "surface:BASE_APP",
    ).call

    assert_equal :authentication_epoch_stale, browser_result.failure_reason

    access_result = OidcAccessTokenAuthenticator.call(
      access_token: access_token,
      resource_type: "client",
      host: OidcIssuer.host_for_resource_type("client"),
    )

    assert_not_predicate access_result, :success?
    assert_equal "invalid_token", access_result.error

    assert_equal :applied, OpIdentityEventInvalidator.call(event:)
    assert_predicate root.reload, :revoked?
  end

  private

  def issuance_flow
    ClientSignInFlow.create!(
      principal_id: @user.id,
      state_id: ClientSignInFlow.state_id_for("SESSION_ISSUANCE_PENDING"),
      nonce_digest: ClientSignInFlow.digest_nonce(SecureRandom.hex(8)),
    )
  end
end
