# frozen_string_literal: true

require "test_helper"
require "timeout"

class StepUpAdmissionRetryCancellationTest < ActionDispatch::IntegrationTest
  self.use_transactional_tests = false
  self.fixture_table_names = []

  test "an APP retry waiting for its parent refuses after cancellation commits" do
    actor = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE)
    token = ClientToken.create!(authentication_epoch: 0, user: actor)
    device = token.device_session_record!
    nonce = SecureRandom.urlsafe_base64(32)
    requirement = StepUpRequirement.new(
      scope: "settings_passkey", purpose: "step_up", step_up_required: true, allowed_methods: [:passkey],
      phishing_resistant_required: false, user_verification_required: false, full_reauthentication_required: false,
      audience: "step_up:app", session_binding: token.public_id, token_binding: token.public_id,
      require_session_binding: true, ttl: 15.minutes, actor_ref: actor.public_id, resource_ref: nil, tenant_ref: nil,
    )
    issuance = BaseStepUpAdmissionIssuer.call!(
      actor:, token:, requirement:, return_to: "/identity/passkeys", base_browser_nonce: nonce, base_token: token,
    )
    binding = ClientAuthAdmissionBinding.find_by!(entry_ref: issuance.reference)
    attached, raw_sid = ClientAuthCeremonySession.issue!
    binding.attach_auth_session!(auth_session: attached, confirmation_ref: SecureRandom.uuid)
    binding.confirm_base!(base_token: token, browser_digest: binding.base_browser_digest)
    browser = open_session
    host = ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
    browser.host!(host)
    browser.https!
    sid_key = JitSessionCookieConfig.force_secure? ? "__Host-auth_sid" : "auth_sid"
    _installed_cookie = browser.cookies.merge("#{sid_key}=#{Rack::Utils.escape(raw_sid)}", URI.parse("https://#{host}/"))
    headers = { "Sec-Fetch-Mode" => "navigate", "Sec-Fetch-Dest" => "document" }
    path = auth_app_verification_path(ri: "jp", entry_ref: issuance.reference)
    browser.get(path, headers:)

    assert_equal 303, browser.response.status
    binding.reload
    admitted_id = binding.admitted_auth_ceremony_session_id
    session_count =
      ClientAuthCeremonySession.where(step_up_ceremony_transaction_ref: issuance.transaction.transaction_id).count
    ready = Queue.new
    worker = nil
    issuance.transaction.with_lock do
      holder_pid = OpBaseAppRecord.lease_connection.select_value("SELECT pg_backend_pid()").to_i
      worker =
        Thread.new do
          OpBaseAppRecord.connection_pool.with_connection(prevent_permanent_checkout: true) do |connection|
            ready << connection.select_value("SELECT pg_backend_pid()").to_i
            browser.get(path, headers:)
            [browser.response.status, browser.response.headers["Set-Cookie"].to_s.match?(/(?:__Host-)?auth_sid=/)]
          end
        ensure
          ActiveRecord::Base.connection_handler.clear_active_connections!
        end
      worker_pid = Timeout.timeout(10) { ready.pop }
      Timeout.timeout(10) do
        loop do
          blocked =
            OpBaseAppRecord.uncached do
              OpBaseAppRecord.lease_connection.select_value(
                "SELECT #{Integer(holder_pid)} = ANY(pg_blocking_pids(#{Integer(worker_pid)}))",
              )
            end
          break if blocked

          raise RuntimeError, "retry finished before waiting for parent" unless worker.alive?

          Thread.pass
        end
      end
      issuance.transaction.commit_cancellation!(now: ClientStepUpCeremonyTransaction.database_now)
    end

    assert_equal [400, false], Timeout.timeout(10) { worker.value }
    assert_equal admitted_id, binding.reload.admitted_auth_ceremony_session_id
    assert_equal session_count,
                 ClientAuthCeremonySession.where(
                   step_up_ceremony_transaction_ref: issuance.transaction.transaction_id,
                 ).count
    assert_predicate issuance.transaction.reload, :canceled?
  ensure
    worker&.join(10)
    if issuance
      bindings = ClientAuthAdmissionBinding.where(step_up_ceremony_transaction_id: issuance.transaction.id)
      ids = bindings.pluck(:auth_ceremony_session_id, :admitted_auth_ceremony_session_id).flatten.compact.uniq
      bindings.delete_all
      ClientAuthCeremonySession.where(id: ids).delete_all
      ClientStepUpSession.where(step_up_ceremony_transaction_ref: issuance.transaction.transaction_id).delete_all
      issuance.transaction.delete
    end
    device&.update!(current_refresh_token_id: nil)
    token&.delete
    device&.delete
    actor&.delete
  end

  test "an APP retry waiting for its actor refuses after its root device is revoked" do
    actor = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE)
    token = ClientToken.create!(authentication_epoch: 0, user: actor)
    device = token.device_session_record!
    nonce = SecureRandom.urlsafe_base64(32)
    requirement = StepUpRequirement.new(
      scope: "settings_passkey", purpose: "step_up", step_up_required: true, allowed_methods: [:passkey],
      phishing_resistant_required: false, user_verification_required: false, full_reauthentication_required: false,
      audience: "step_up:app", session_binding: token.public_id, token_binding: token.public_id,
      require_session_binding: true, ttl: 15.minutes, actor_ref: actor.public_id, resource_ref: nil, tenant_ref: nil,
    )
    issuance = BaseStepUpAdmissionIssuer.call!(
      actor:, token:, requirement:, return_to: "/identity/passkeys", base_browser_nonce: nonce, base_token: token,
    )
    binding = ClientAuthAdmissionBinding.find_by!(entry_ref: issuance.reference)
    attached, raw_sid = ClientAuthCeremonySession.issue!
    binding.attach_auth_session!(auth_session: attached, confirmation_ref: SecureRandom.uuid)
    binding.confirm_base!(base_token: token, browser_digest: binding.base_browser_digest)
    browser = open_session
    host = ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
    browser.host!(host)
    browser.https!
    sid_key = JitSessionCookieConfig.force_secure? ? "__Host-auth_sid" : "auth_sid"
    _installed_cookie = browser.cookies.merge("#{sid_key}=#{Rack::Utils.escape(raw_sid)}", URI.parse("https://#{host}/"))
    headers = { "Sec-Fetch-Mode" => "navigate", "Sec-Fetch-Dest" => "document" }
    path = auth_app_verification_path(ri: "jp", entry_ref: issuance.reference)
    browser.get(path, headers:)

    assert_equal 303, browser.response.status
    binding.reload
    admitted_id = binding.admitted_auth_ceremony_session_id
    session_count =
      ClientAuthCeremonySession.where(step_up_ceremony_transaction_ref: issuance.transaction.transaction_id).count
    ready = Queue.new
    worker = nil
    actor.with_lock do
      holder_pid = Client.lease_connection.select_value("SELECT pg_backend_pid()").to_i
      worker =
        Thread.new do
          Client.connection_pool.with_connection(prevent_permanent_checkout: true) do |connection|
            ready << connection.select_value("SELECT pg_backend_pid()").to_i
            browser.get(path, headers:)
            [browser.response.status, browser.response.headers["Set-Cookie"].to_s.match?(/(?:__Host-)?auth_sid=/)]
          end
        ensure
          ActiveRecord::Base.connection_handler.clear_active_connections!
        end
      worker_pid = Timeout.timeout(10) { ready.pop }
      Timeout.timeout(10) do
        loop do
          blocked =
            Client.uncached do
              Client.lease_connection.select_value(
                "SELECT #{Integer(holder_pid)} = ANY(pg_blocking_pids(#{Integer(worker_pid)}))",
              )
            end
          break if blocked

          unless worker.alive?
            result = worker.value
            raise RuntimeError, "retry finished before waiting for actor: #{result.inspect}"
          end

          Thread.pass
        end
      end
      device.revoke!
    end

    assert_equal [400, false], Timeout.timeout(10) { worker.value }
    assert_equal admitted_id, binding.reload.admitted_auth_ceremony_session_id
    assert_equal session_count,
                 ClientAuthCeremonySession.where(
                   step_up_ceremony_transaction_ref: issuance.transaction.transaction_id,
                 ).count
    assert_predicate device.reload, :revoked?
    assert_equal "pending", issuance.transaction.reload.status
  ensure
    worker&.join(10)
    if issuance
      bindings = ClientAuthAdmissionBinding.where(step_up_ceremony_transaction_id: issuance.transaction.id)
      ids = bindings.pluck(:auth_ceremony_session_id, :admitted_auth_ceremony_session_id).flatten.compact.uniq
      bindings.delete_all
      ClientAuthCeremonySession.where(id: ids).delete_all
      ClientStepUpSession.where(step_up_ceremony_transaction_ref: issuance.transaction.transaction_id).delete_all
      issuance.transaction.delete
    end
    device&.update!(current_refresh_token_id: nil)
    token&.delete
    device&.delete
    actor&.delete
  end

  test "an ORG retry waiting for its actor refuses after its root device is revoked" do
    actor = Operator.create!(security_mode_id: SecurityModeConfigurable::ADVANCED)
    token = OperatorToken.create!(authentication_epoch: 0, staff: actor)
    device = token.device_session_record!
    nonce = SecureRandom.urlsafe_base64(32)
    requirement = StepUpRequirement.new(
      scope: "settings_passkey", purpose: "step_up", step_up_required: true, allowed_methods: [:passkey],
      phishing_resistant_required: false, user_verification_required: false, full_reauthentication_required: false,
      audience: "step_up:org", session_binding: token.public_id, token_binding: token.public_id,
      require_session_binding: true, ttl: 15.minutes, actor_ref: actor.public_id, resource_ref: nil, tenant_ref: nil,
    )
    issuance = BaseStepUpAdmissionIssuer.call!(
      actor:, token:, requirement:, return_to: "/identity/passkeys", base_browser_nonce: nonce, base_token: token,
    )
    binding = OperatorAuthAdmissionBinding.find_by!(entry_ref: issuance.reference)
    attached, raw_sid = OperatorAuthCeremonySession.issue!
    binding.attach_auth_session!(auth_session: attached, confirmation_ref: SecureRandom.uuid)
    binding.confirm_base!(base_token: token, browser_digest: binding.base_browser_digest)
    browser = open_session
    host = ENV.fetch("PUBLIC_AUTH_STAFF_URL")
    browser.host!(host)
    browser.https!
    sid_key = JitSessionCookieConfig.force_secure? ? "__Host-auth_sid" : "auth_sid"
    _installed_cookie = browser.cookies.merge("#{sid_key}=#{Rack::Utils.escape(raw_sid)}", URI.parse("https://#{host}/"))
    headers = { "Sec-Fetch-Mode" => "navigate", "Sec-Fetch-Dest" => "document" }
    path = auth_org_verification_path(ri: "jp", entry_ref: issuance.reference)
    browser.get(path, headers:)

    assert_equal 303, browser.response.status
    binding.reload
    admitted_id = binding.admitted_auth_ceremony_session_id
    session_count =
      OperatorAuthCeremonySession.where(step_up_ceremony_transaction_ref: issuance.transaction.transaction_id).count
    ready = Queue.new
    worker = nil
    actor.with_lock do
      holder_pid = Operator.lease_connection.select_value("SELECT pg_backend_pid()").to_i
      worker =
        Thread.new do
          Operator.connection_pool.with_connection(prevent_permanent_checkout: true) do |connection|
            ready << connection.select_value("SELECT pg_backend_pid()").to_i
            browser.get(path, headers:)
            [browser.response.status, browser.response.headers["Set-Cookie"].to_s.match?(/(?:__Host-)?auth_sid=/)]
          end
        ensure
          ActiveRecord::Base.connection_handler.clear_active_connections!
        end
      worker_pid = Timeout.timeout(10) { ready.pop }
      Timeout.timeout(10) do
        loop do
          blocked =
            Operator.uncached do
              Operator.lease_connection.select_value(
                "SELECT #{Integer(holder_pid)} = ANY(pg_blocking_pids(#{Integer(worker_pid)}))",
              )
            end
          break if blocked

          unless worker.alive?
            result = worker.value
            raise RuntimeError, "retry finished before waiting for actor: #{result.inspect}"
          end

          Thread.pass
        end
      end
      device.revoke!
    end

    assert_equal [400, false], Timeout.timeout(10) { worker.value }
    assert_equal admitted_id, binding.reload.admitted_auth_ceremony_session_id
    assert_equal session_count,
                 OperatorAuthCeremonySession.where(
                   step_up_ceremony_transaction_ref: issuance.transaction.transaction_id,
                 ).count
    assert_predicate device.reload, :revoked?
    assert_equal "pending", issuance.transaction.reload.status
  ensure
    worker&.join(10)
    if issuance
      bindings = OperatorAuthAdmissionBinding.where(step_up_ceremony_transaction_id: issuance.transaction.id)
      ids = bindings.pluck(:auth_ceremony_session_id, :admitted_auth_ceremony_session_id).flatten.compact.uniq
      bindings.delete_all
      OperatorAuthCeremonySession.where(id: ids).delete_all
      OperatorStepUpSession.where(step_up_ceremony_transaction_ref: issuance.transaction.transaction_id).delete_all
      issuance.transaction.delete
    end
    device&.update!(current_refresh_token_id: nil)
    token&.delete
    device&.delete
    actor&.delete
  end

  test "an ORG retry waiting for its parent refuses after cancellation commits" do
    actor = Operator.create!(security_mode_id: SecurityModeConfigurable::ADVANCED)
    token = OperatorToken.create!(authentication_epoch: 0, staff: actor)
    device = token.device_session_record!
    nonce = SecureRandom.urlsafe_base64(32)
    requirement = StepUpRequirement.new(
      scope: "settings_passkey", purpose: "step_up", step_up_required: true, allowed_methods: [:passkey],
      phishing_resistant_required: false, user_verification_required: false, full_reauthentication_required: false,
      audience: "step_up:org", session_binding: token.public_id, token_binding: token.public_id,
      require_session_binding: true, ttl: 15.minutes, actor_ref: actor.public_id, resource_ref: nil, tenant_ref: nil,
    )
    issuance = BaseStepUpAdmissionIssuer.call!(
      actor:, token:, requirement:, return_to: "/identity/passkeys", base_browser_nonce: nonce, base_token: token,
    )
    binding = OperatorAuthAdmissionBinding.find_by!(entry_ref: issuance.reference)
    attached, raw_sid = OperatorAuthCeremonySession.issue!
    binding.attach_auth_session!(auth_session: attached, confirmation_ref: SecureRandom.uuid)
    binding.confirm_base!(base_token: token, browser_digest: binding.base_browser_digest)
    browser = open_session
    host = ENV.fetch("PUBLIC_AUTH_STAFF_URL")
    browser.host!(host)
    browser.https!
    sid_key = JitSessionCookieConfig.force_secure? ? "__Host-auth_sid" : "auth_sid"
    _installed_cookie = browser.cookies.merge("#{sid_key}=#{Rack::Utils.escape(raw_sid)}", URI.parse("https://#{host}/"))
    headers = { "Sec-Fetch-Mode" => "navigate", "Sec-Fetch-Dest" => "document" }
    path = auth_org_verification_path(ri: "jp", entry_ref: issuance.reference)
    browser.get(path, headers:)

    assert_equal 303, browser.response.status
    binding.reload
    admitted_id = binding.admitted_auth_ceremony_session_id
    session_count =
      OperatorAuthCeremonySession.where(step_up_ceremony_transaction_ref: issuance.transaction.transaction_id).count
    ready = Queue.new
    worker = nil
    issuance.transaction.with_lock do
      holder_pid = OpBaseOrgRecord.lease_connection.select_value("SELECT pg_backend_pid()").to_i
      worker =
        Thread.new do
          OpBaseOrgRecord.connection_pool.with_connection(prevent_permanent_checkout: true) do |connection|
            ready << connection.select_value("SELECT pg_backend_pid()").to_i
            browser.get(path, headers:)
            [browser.response.status, browser.response.headers["Set-Cookie"].to_s.match?(/(?:__Host-)?auth_sid=/)]
          end
        ensure
          ActiveRecord::Base.connection_handler.clear_active_connections!
        end
      worker_pid = Timeout.timeout(10) { ready.pop }
      Timeout.timeout(10) do
        loop do
          blocked =
            OpBaseOrgRecord.uncached do
              OpBaseOrgRecord.lease_connection.select_value(
                "SELECT #{Integer(holder_pid)} = ANY(pg_blocking_pids(#{Integer(worker_pid)}))",
              )
            end
          break if blocked

          raise RuntimeError, "retry finished before waiting for parent" unless worker.alive?

          Thread.pass
        end
      end
      issuance.transaction.commit_cancellation!(now: OperatorStepUpCeremonyTransaction.database_now)
    end

    assert_equal [400, false], Timeout.timeout(10) { worker.value }
    assert_equal admitted_id, binding.reload.admitted_auth_ceremony_session_id
    assert_equal session_count,
                 OperatorAuthCeremonySession.where(
                   step_up_ceremony_transaction_ref: issuance.transaction.transaction_id,
                 ).count
    assert_predicate issuance.transaction.reload, :canceled?
  ensure
    worker&.join(10)
    if issuance
      bindings = OperatorAuthAdmissionBinding.where(step_up_ceremony_transaction_id: issuance.transaction.id)
      ids = bindings.pluck(:auth_ceremony_session_id, :admitted_auth_ceremony_session_id).flatten.compact.uniq
      bindings.delete_all
      OperatorAuthCeremonySession.where(id: ids).delete_all
      OperatorStepUpSession.where(step_up_ceremony_transaction_ref: issuance.transaction.transaction_id).delete_all
      issuance.transaction.delete
    end
    device&.update!(current_refresh_token_id: nil)
    token&.delete
    device&.delete
    actor&.delete
  end
end
