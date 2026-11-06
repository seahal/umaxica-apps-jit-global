# frozen_string_literal: true

require "test_helper"
require "timeout"

class StepUpAdmissionRetryCancellationTest < ActionDispatch::IntegrationTest
  self.use_transactional_tests = false
  self.fixture_table_names = []

  test "an APP retry waiting for its parent refuses after cancellation commits" do
    actor = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE)
    credential = actor.client_passkeys.create!(webauthn_id: SecureRandom.uuid, public_key: "public", sign_count: 0)
    token = ClientToken.create!(authentication_epoch: 0, user: actor)
    device = token.device_session_record!
    client = OidcClientRegistry.find!("core-app-jp")
    now = OpBaseAppRecord.database_now
    grant = OpAppGrant.create!(
      authentication_epoch: token.authentication_epoch, client_token: token, oidc_client_id: client.client_id,
      oidc_scope: "openid profile", oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16),
      oidc_auth_time: now - 1.hour, refresh_token_expires_at: now + 1.hour,
    )
    grant.issue_refresh_token!(expires_at: now + 1.hour, now:)
    params = {
      response_type: "code",
      client_id: client.client_id,
      redirect_uri: client.redirect_uris_by_realm.fetch("client").first,
      scope: grant.oidc_scope,
      state: SecureRandom.urlsafe_base64(32),
      nonce: SecureRandom.urlsafe_base64(32),
      code_challenge: Base64.urlsafe_encode64(Digest::SHA256.digest("app-retry-cancel"), padding: false),
      code_challenge_method: "S256",
      prompt: "login",
      claims: OidcAuthorizeRequestResolver::STEP_UP_CLAIMS,
    }
    validated_request = OidcAuthorizeRequestResolver.call(params:, resource: actor, resource_type: "client")
    issuance = OidcStepUpAuthorizationIssuer.call!(
      surface: "app", actor:, token:, client:, params:, validated_request:,
    )
    transaction = issuance.ticket
    context = issuance.context
    authorization = issuance.authorization_transaction
    binding = ClientAuthAdmissionBinding.find_by!(entry_ref: issuance.entry_ref)
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
    path = auth_app_verification_path(ri: "jp", entry_ref: issuance.entry_ref)
    browser.get(path, headers:)

    assert_equal 303, browser.response.status
    binding.reload
    admitted_id = binding.admitted_auth_ceremony_session_id
    session_count =
      ClientAuthCeremonySession.where(step_up_ceremony_transaction_ref: transaction.transaction_id).count
    ready = Queue.new
    worker = nil
    transaction.with_lock do
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
      transaction.commit_cancellation!(now: ClientStepUpCeremonyTransaction.database_now)
    end

    assert_equal [400, false], Timeout.timeout(10) { worker.value }
    assert_equal admitted_id, binding.reload.admitted_auth_ceremony_session_id
    assert_equal session_count,
                 ClientAuthCeremonySession.where(
                   step_up_ceremony_transaction_ref: transaction.transaction_id,
                 ).count
    assert_predicate transaction.reload, :canceled?
  ensure
    worker&.join(10)
    if transaction
      bindings = ClientAuthAdmissionBinding.where(step_up_ceremony_transaction_id: transaction.id)
      ids = bindings.pluck(:auth_ceremony_session_id, :admitted_auth_ceremony_session_id).flatten.compact.uniq
      bindings.delete_all
      ClientAuthCeremonySession.where(id: ids).delete_all
      ClientStepUpSession.where(step_up_ceremony_transaction_ref: transaction.transaction_id).delete_all
      transaction.delete
    end
    context&.delete
    authorization&.delete
    grant&.delete
    credential&.delete
    device&.update!(current_refresh_token_id: nil)
    token&.delete
    device&.delete
    actor&.delete
  end

  test "an APP retry waiting for its actor refuses after its root device is revoked" do
    actor = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE)
    credential = actor.client_passkeys.create!(webauthn_id: SecureRandom.uuid, public_key: "public", sign_count: 0)
    token = ClientToken.create!(authentication_epoch: 0, user: actor)
    device = token.device_session_record!
    client = OidcClientRegistry.find!("core-app-jp")
    now = OpBaseAppRecord.database_now
    grant = OpAppGrant.create!(
      authentication_epoch: token.authentication_epoch, client_token: token, oidc_client_id: client.client_id,
      oidc_scope: "openid profile", oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16),
      oidc_auth_time: now - 1.hour, refresh_token_expires_at: now + 1.hour,
    )
    grant.issue_refresh_token!(expires_at: now + 1.hour, now:)
    params = {
      response_type: "code",
      client_id: client.client_id,
      redirect_uri: client.redirect_uris_by_realm.fetch("client").first,
      scope: grant.oidc_scope,
      state: SecureRandom.urlsafe_base64(32),
      nonce: SecureRandom.urlsafe_base64(32),
      code_challenge: Base64.urlsafe_encode64(Digest::SHA256.digest("app-retry-actor"), padding: false),
      code_challenge_method: "S256",
      prompt: "login",
      claims: OidcAuthorizeRequestResolver::STEP_UP_CLAIMS,
    }
    validated_request = OidcAuthorizeRequestResolver.call(params:, resource: actor, resource_type: "client")
    issuance = OidcStepUpAuthorizationIssuer.call!(
      surface: "app", actor:, token:, client:, params:, validated_request:,
    )
    transaction = issuance.ticket
    context = issuance.context
    authorization = issuance.authorization_transaction
    binding = ClientAuthAdmissionBinding.find_by!(entry_ref: issuance.entry_ref)
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
    path = auth_app_verification_path(ri: "jp", entry_ref: issuance.entry_ref)
    browser.get(path, headers:)

    assert_equal 303, browser.response.status
    binding.reload
    admitted_id = binding.admitted_auth_ceremony_session_id
    session_count =
      ClientAuthCeremonySession.where(step_up_ceremony_transaction_ref: transaction.transaction_id).count
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
                   step_up_ceremony_transaction_ref: transaction.transaction_id,
                 ).count
    assert_predicate device.reload, :revoked?
    assert_equal "pending", transaction.reload.status
  ensure
    worker&.join(10)
    if transaction
      bindings = ClientAuthAdmissionBinding.where(step_up_ceremony_transaction_id: transaction.id)
      ids = bindings.pluck(:auth_ceremony_session_id, :admitted_auth_ceremony_session_id).flatten.compact.uniq
      bindings.delete_all
      ClientAuthCeremonySession.where(id: ids).delete_all
      ClientStepUpSession.where(step_up_ceremony_transaction_ref: transaction.transaction_id).delete_all
      transaction.delete
    end
    context&.delete
    authorization&.delete
    grant&.delete
    credential&.delete
    device&.update!(current_refresh_token_id: nil)
    token&.delete
    device&.delete
    actor&.delete
  end

  test "an ORG retry waiting for its actor refuses after its root device is revoked" do
    actor = Operator.create!(
      security_mode_id: SecurityModeConfigurable::ADVANCED, status_id: OperatorStatus::ACTIVE,
      visibility_id: OperatorVisibility::STAFF,
    )
    credential = actor.staff_passkeys.create!(webauthn_id: SecureRandom.uuid, public_key: "public", sign_count: 0)
    token = OperatorToken.create!(authentication_epoch: 0, staff: actor)
    device = token.device_session_record!
    client = OidcClientRegistry.find!("core-org-jp")
    now = OpBaseOrgRecord.database_now
    grant = OpOrgGrant.create!(
      authentication_epoch: token.authentication_epoch, operator_token: token, oidc_client_id: client.client_id,
      oidc_scope: "openid profile", oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16),
      oidc_auth_time: now - 1.hour, refresh_token_expires_at: now + 1.hour,
    )
    grant.issue_refresh_token!(expires_at: now + 1.hour, now:)
    params = {
      response_type: "code",
      client_id: client.client_id,
      redirect_uri: client.redirect_uris_by_realm.fetch("operator").first,
      scope: grant.oidc_scope,
      state: SecureRandom.urlsafe_base64(32),
      nonce: SecureRandom.urlsafe_base64(32),
      code_challenge: Base64.urlsafe_encode64(Digest::SHA256.digest("org-retry-actor"), padding: false),
      code_challenge_method: "S256",
      prompt: "login",
      claims: OidcAuthorizeRequestResolver::STEP_UP_CLAIMS,
    }
    validated_request = OidcAuthorizeRequestResolver.call(params:, resource: actor, resource_type: "operator")
    issuance = OidcStepUpAuthorizationIssuer.call!(
      surface: "org", actor:, token:, client:, params:, validated_request:,
    )
    transaction = issuance.ticket
    context = issuance.context
    authorization = issuance.authorization_transaction
    binding = OperatorAuthAdmissionBinding.find_by!(entry_ref: issuance.entry_ref)
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
    path = auth_org_verification_path(ri: "jp", entry_ref: issuance.entry_ref)
    browser.get(path, headers:)

    assert_equal 303, browser.response.status
    binding.reload
    admitted_id = binding.admitted_auth_ceremony_session_id
    session_count =
      OperatorAuthCeremonySession.where(step_up_ceremony_transaction_ref: transaction.transaction_id).count
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
                   step_up_ceremony_transaction_ref: transaction.transaction_id,
                 ).count
    assert_predicate device.reload, :revoked?
    assert_equal "pending", transaction.reload.status
  ensure
    worker&.join(10)
    if transaction
      bindings = OperatorAuthAdmissionBinding.where(step_up_ceremony_transaction_id: transaction.id)
      ids = bindings.pluck(:auth_ceremony_session_id, :admitted_auth_ceremony_session_id).flatten.compact.uniq
      bindings.delete_all
      OperatorAuthCeremonySession.where(id: ids).delete_all
      OperatorStepUpSession.where(step_up_ceremony_transaction_ref: transaction.transaction_id).delete_all
      transaction.delete
    end
    context&.delete
    authorization&.delete
    grant&.delete
    credential&.delete
    device&.update!(current_refresh_token_id: nil)
    token&.delete
    device&.delete
    actor&.delete
  end

  test "an ORG retry waiting for its parent refuses after cancellation commits" do
    actor = Operator.create!(
      security_mode_id: SecurityModeConfigurable::ADVANCED, status_id: OperatorStatus::ACTIVE,
      visibility_id: OperatorVisibility::STAFF,
    )
    credential = actor.staff_passkeys.create!(webauthn_id: SecureRandom.uuid, public_key: "public", sign_count: 0)
    token = OperatorToken.create!(authentication_epoch: 0, staff: actor)
    device = token.device_session_record!
    client = OidcClientRegistry.find!("core-org-jp")
    now = OpBaseOrgRecord.database_now
    grant = OpOrgGrant.create!(
      authentication_epoch: token.authentication_epoch, operator_token: token, oidc_client_id: client.client_id,
      oidc_scope: "openid profile", oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16),
      oidc_auth_time: now - 1.hour, refresh_token_expires_at: now + 1.hour,
    )
    grant.issue_refresh_token!(expires_at: now + 1.hour, now:)
    params = {
      response_type: "code",
      client_id: client.client_id,
      redirect_uri: client.redirect_uris_by_realm.fetch("operator").first,
      scope: grant.oidc_scope,
      state: SecureRandom.urlsafe_base64(32),
      nonce: SecureRandom.urlsafe_base64(32),
      code_challenge: Base64.urlsafe_encode64(Digest::SHA256.digest("org-retry-cancel"), padding: false),
      code_challenge_method: "S256",
      prompt: "login",
      claims: OidcAuthorizeRequestResolver::STEP_UP_CLAIMS,
    }
    validated_request = OidcAuthorizeRequestResolver.call(params:, resource: actor, resource_type: "operator")
    issuance = OidcStepUpAuthorizationIssuer.call!(
      surface: "org", actor:, token:, client:, params:, validated_request:,
    )
    transaction = issuance.ticket
    context = issuance.context
    authorization = issuance.authorization_transaction
    binding = OperatorAuthAdmissionBinding.find_by!(entry_ref: issuance.entry_ref)
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
    path = auth_org_verification_path(ri: "jp", entry_ref: issuance.entry_ref)
    browser.get(path, headers:)

    assert_equal 303, browser.response.status
    binding.reload
    admitted_id = binding.admitted_auth_ceremony_session_id
    session_count =
      OperatorAuthCeremonySession.where(step_up_ceremony_transaction_ref: transaction.transaction_id).count
    ready = Queue.new
    worker = nil
    transaction.with_lock do
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
      transaction.commit_cancellation!(now: OperatorStepUpCeremonyTransaction.database_now)
    end

    assert_equal [400, false], Timeout.timeout(10) { worker.value }
    assert_equal admitted_id, binding.reload.admitted_auth_ceremony_session_id
    assert_equal session_count,
                 OperatorAuthCeremonySession.where(
                   step_up_ceremony_transaction_ref: transaction.transaction_id,
                 ).count
    assert_predicate transaction.reload, :canceled?
  ensure
    worker&.join(10)
    if transaction
      bindings = OperatorAuthAdmissionBinding.where(step_up_ceremony_transaction_id: transaction.id)
      ids = bindings.pluck(:auth_ceremony_session_id, :admitted_auth_ceremony_session_id).flatten.compact.uniq
      bindings.delete_all
      OperatorAuthCeremonySession.where(id: ids).delete_all
      OperatorStepUpSession.where(step_up_ceremony_transaction_ref: transaction.transaction_id).delete_all
      transaction.delete
    end
    context&.delete
    authorization&.delete
    grant&.delete
    credential&.delete
    device&.update!(current_refresh_token_id: nil)
    token&.delete
    device&.delete
    actor&.delete
  end
end
