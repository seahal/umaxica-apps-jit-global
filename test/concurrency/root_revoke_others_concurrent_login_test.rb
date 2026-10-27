# frozen_string_literal: true

require "test_helper"
require "timeout"
require_relative "../support/authority_stop_cleanup"

class RootRevokeOthersConcurrentLoginTest < ActiveSupport::TestCase
  include AuthorityStopCleanup

  self.use_transactional_tests = false
  self.fixture_table_names = []

  setup do
    @original_login_cooldown = login_cooldown
    self.login_cooldown = 0.seconds
    ClientIdentityState.ensure_defaults!
    ClientTokenKind.find_or_create_by!(id: ClientTokenKind::BROWSER_WEB)
    ClientTokenStatus.find_or_create_by!(id: ClientTokenStatus::ACTIVE)
    @actor = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE)
    @current_root = ClientToken.create!(
      authentication_epoch: @actor.authentication_epoch,
      user: @actor,
      user_token_kind_id: ClientTokenKind::BROWSER_WEB,
      user_token_status_id: ClientTokenStatus::ACTIVE,
    )
    @existing_root = ClientToken.create!(
      authentication_epoch: @actor.authentication_epoch,
      user: @actor,
      user_token_kind_id: ClientTokenKind::BROWSER_WEB,
      user_token_status_id: ClientTokenStatus::ACTIVE,
    )
    step_up_at = ClientToken.database_now
    @current_root.update!(
      last_step_up_at: step_up_at,
      last_step_up_scope: "session_revoke_all",
      last_step_up_method: "passkey",
      last_step_up_session_public_id: @current_root.public_id,
      last_step_up_purpose: "step_up",
      last_step_up_audience: "step_up:app",
      last_step_up_phishing_resistant: false,
      last_step_up_user_verified: false,
      last_step_up_credential_ref: "test-step-up",
      last_step_up_full_reauthentication: false,
    )
    @step_up_requirement = StepUpRequirement.new(
      scope: "session_revoke_all",
      step_up_required: true,
      allowed_methods: %i(passkey totp email_otp),
      phishing_resistant_required: false,
      user_verification_required: false,
      full_reauthentication_required: false,
      purpose: "step_up",
      audience: "step_up:app",
      session_binding: @current_root.public_id,
      token_binding: @current_root.public_id,
      require_session_binding: true,
      ttl: StepUpRequirement::DEFAULT_TTL,
      actor_ref: @actor.public_id,
      resource_ref: nil,
      tenant_ref: nil,
    )
    @login_flow = ClientSignInFlow.create!(
      principal_id: @actor.id,
      state_id: ClientSignInFlow.state_id_for("SESSION_ISSUANCE_PENDING"),
      nonce_digest: ClientSignInFlow.digest_nonce(SecureRandom.hex(8)),
    )
    ActiveRecord::Base.connection_handler.clear_active_connections!
  end

  teardown do
    root_ids = ClientToken.where(user_id: @actor&.id).pluck(:id)
    grant_ids = OpAppGrant.where(client_token_id: root_ids).pluck(:id)
    delete_authority_stops_for!(realm: "app", root_ids:, grant_ids:)
    OpAppGrant.where(id: grant_ids).delete_all
    device_session_ids = ClientToken.where(id: root_ids).where.not(device_session_id: nil).pluck(:device_session_id)
    ClientToken.where(id: root_ids).delete_all
    ClientDeviceSession.where(id: device_session_ids).delete_all
    ClientSignInFlow.where(id: @login_flow&.id).delete_all
    Client.where(id: @actor&.id).delete_all
    self.login_cooldown = @original_login_cooldown if @original_login_cooldown
    ActiveRecord::Base.connection_handler.clear_active_connections!
  end

  test "A44-10 revoke-others snapshots existing roots before a concurrent Root login commits" do
    lock_ready = Queue.new
    release_root_lock = Queue.new
    revoker_ready = Queue.new
    locker_thread =
      Thread.new do
        OpBaseAppRecord.connection_pool.with_connection do |connection|
          OpBaseAppRecord.transaction do
            connection.execute("SET lock_timeout = '10s'")
            ClientToken.lock.find(@existing_root.id)
            lock_ready << connection.select_value("SELECT pg_backend_pid()")
            release_root_lock.pop
          end
        end
      end
    lock_pid = Timeout.timeout(10) { lock_ready.pop }
    revoker_thread =
      Thread.new do
        OpBaseAppRecord.connection_pool.with_connection do |connection|
          connection.execute("SET lock_timeout = '10s'")
          pid = connection.select_value("SELECT pg_backend_pid()")
          revoker_ready << pid
          AuthenticationOtherSessionsRevoker.call(
            owner: Client.find(@actor.id),
            sessions: ClientToken.where(user_id: @actor.id).session_inventory,
            current_token: ClientToken.find(@current_root.id),
            current_session_public_id: @current_root.public_id,
            step_up_requirement: @step_up_requirement,
          )
        end
      end
    revoker_pid = Timeout.timeout(10) { revoker_ready.pop }

    Timeout.timeout(10) do
      loop do
        wait_event =
          OpBaseAppRecord.connection_pool.with_connection do |connection|
            connection.select_value("SELECT wait_event_type FROM pg_stat_activity WHERE pid = #{Integer(revoker_pid)}")
          end
        break if wait_event == "Lock"

        Thread.pass
      end
    end

    login_result = Queue.new
    login_thread =
      Thread.new do
        controller = Base::App::AuthorityController.new
        request = ActionDispatch::TestRequest.create
        request.host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
        request.set_header("HTTPS", "on")
        request.session = ActionController::TestSession.new
        controller.request = request
        controller.response = ActionDispatch::TestResponse.new
        login_result << controller.log_in(
          Client.find(@actor.id),
          establishment: :root_login,
          require_totp_check: false,
          sign_in_flow: ClientSignInFlow.find(@login_flow.id),
        )
      end

    login = Timeout.timeout(10) { login_result.pop }

    assert_equal :success, login.fetch(:status)
    new_root = ClientToken.where(user_id: @actor.id).where.not(id: [@current_root.id, @existing_root.id]).sole
    release_root_lock << true
    revocation = Timeout.timeout(10) { revoker_thread.value }
    locker_thread.value

    assert_predicate revocation, :success?
    assert_equal [@existing_root.public_id], revocation.revoked_tokens.map(&:public_id)
    assert_predicate @existing_root.reload, :revoked?
    assert_predicate @current_root.reload, :currently_usable?
    assert_predicate new_root.reload, :currently_usable?
    assert_equal @actor.authentication_epoch, new_root.authentication_epoch
    assert_not_equal lock_pid, revoker_pid
    browser_result = AuthenticationCurrentResourceResolver.new(
      access_token: jwt_access_token_for(
        @actor.reload,
        host: ENV.fetch("PUBLIC_BASE_SERVICE_URL"),
        session_public_id: new_root.public_id,
        resource_type: "client",
      ),
      request_host: ENV.fetch("PUBLIC_BASE_SERVICE_URL"),
      resource_type: "client",
      resource_class: Client,
      token_class: ClientToken,
      jwt_issuer_id: "surface:BASE_APP",
    ).call

    assert_predicate browser_result, :success?
    assert_equal new_root.public_id, browser_result.token_public_id
  ensure
    release_root_lock << true if release_root_lock
    [locker_thread, revoker_thread, login_thread].compact.each do |thread|
      thread.kill unless thread.join(10)
    end
  end
end
