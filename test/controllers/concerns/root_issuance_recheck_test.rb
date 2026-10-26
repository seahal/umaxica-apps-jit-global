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
  test "a stop committed after the Root insert revokes that Root through the identity-stop apply" do
    result = @controller.log_in(
      Client.find(@user.id), establishment: :root_login, require_totp_check: false, sign_in_flow: issuance_flow,
    )

    assert_equal :success, result.fetch(:status)
    root = ClientToken.where(user_id: @user.id).sole

    event =
      Client.transaction do
        IdentityAuthenticationStopRecorder.call(actor: Client.lock.find(@user.id), reason: "withdrawal_suspend")
      end

    assert_not AuthenticationEpochValue.root_current?(root_token: root.reload, actor: @user.reload)
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
