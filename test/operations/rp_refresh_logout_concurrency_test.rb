# frozen_string_literal: true

require "test_helper"
require "timeout"

class RpRefreshLogoutConcurrencyTest < ActiveSupport::TestCase
  self.use_transactional_tests = false
  self.fixture_table_names = []

  test "unknown sid callback logout and duplicate delivery serialize on independent connections" do
    cell = RpCellBinding.fetch("rp_core_app")
    issuer = "https://op.example.test"
    suffix = SecureRandom.hex(12)
    workers = []
    releases = []
    %i(callback_first logout_first duplicate_logout).each_with_index do |ordering, index|
      callback_first = ordering == :callback_first
      sid = "unknown-#{suffix}-#{index}"
      first_ready = Queue.new
      second_ready = Queue.new
      release = Queue.new
      releases << release
      results = Queue.new
      callback =
        -> {
          RpCallbackCommitter.call(
            cell: cell, issuer: issuer, subject: "subject-#{suffix}", sid: sid,
            absolute_expires_at: 1.hour.from_now, contract_epoch: 1,
          ).outcome
        }
      logout =
        -> {
          RpCellSessionRevoker.call(
            cell: cell, payload: { "iss" => issuer,
                                   "sid" => sid,
                                   "jti" => "logout-#{sid}",
                                   "exp" => 5.minutes.from_now.to_i, },
          )
        }
      first_operation, second_operation =
        case ordering
        when :callback_first then [callback, logout]
        when :logout_first then [logout, callback]
        when :duplicate_logout then [logout, logout]
        end
      workers << Thread.new do
        RpCoreAppRecord.connection_pool.with_connection do |connection|
          outcome =
            RpCoreAppRecord.transaction do
              result = first_operation.call
              first_ready << [connection.select_value("SELECT pg_backend_pid()"), result]
              release.pop
              result
            end
          results << outcome
        end
      rescue StandardError => e
        results << e
      end
      first_pid, first_outcome = Timeout.timeout(10) { first_ready.pop }

      assert_equal callback_first ? :committed : :revoked, first_outcome

      workers << Thread.new do
        RpCoreAppRecord.connection_pool.with_connection do |connection|
          second_ready << connection.select_value("SELECT pg_backend_pid()")
          results << second_operation.call
        end
      rescue StandardError => e
        results << e
      end
      second_pid = Timeout.timeout(10) { second_ready.pop }

      assert_not_equal first_pid, second_pid
      Timeout.timeout(10) do
        loop do
          waiting =
            RpCoreAppRecord.uncached do
              RpCoreAppRecord.lease_connection.select_value(
                "SELECT wait_event_type FROM pg_stat_activity WHERE pid = #{Integer(second_pid)}",
              )
            end
          break if waiting == "Lock"

          Thread.pass
        end
      end
      release << true
      outcomes = 2.times.map { Timeout.timeout(10) { results.pop } }
      outcomes.each { |outcome| raise outcome if outcome.is_a?(Exception) }

      expected =
        case ordering
        when :callback_first then [:committed, :revoked]
        when :logout_first then [:revoked, :revoked]
        when :duplicate_logout then [:duplicate, :revoked]
        end

      assert_equal expected, outcomes.sort
      anchor = RpCoreAppOpSessionBinding.find_by!(issuer: issuer, sid: sid)

      assert_not_nil anchor.revoked_at
      assert_equal callback_first ? 1 : 0, RpCoreAppSession.where(op_session_binding_id: anchor.id).count
      assert_not RpCoreAppSession.exists?(op_session_binding_id: anchor.id, revoked_at: nil)
      assert_equal 1, RpCoreAppEventReceipt.where(op_session_binding_id: anchor.id).count
    end
  ensure
    releases&.each { |release| release << true }
    workers&.each { |worker| worker.join(10) }
    if suffix
      anchors = RpCoreAppOpSessionBinding.where(
        issuer: issuer,
        sid: [
          "unknown-#{suffix}-0", "unknown-#{suffix}-1", "unknown-#{suffix}-2",
        ],
      )
      RpCoreAppSession.where(op_session_binding_id: anchors.select(:id)).delete_all
      RpCoreAppEventReceipt.where(op_session_binding_id: anchors.select(:id)).delete_all
      anchors.delete_all
      identities = RpCoreAppIdentityBinding.where(issuer: issuer, subject: "subject-#{suffix}")
      principal_ids = identities.pluck(:principal_id)
      identities.delete_all
      RpCoreAppPrincipal.where(id: principal_ids).delete_all
    end
  end

  test "logout committed on another connection denies a cached reading caller's request and callback" do
    cell = RpCellBinding.fetch("rp_core_app")
    issuer = "https://op.example.test"
    suffix = SecureRandom.hex(12)
    session = RpCallbackCommitter.call(
      cell: cell, issuer: issuer, subject: "subject-#{suffix}", sid: "sid-#{suffix}",
      absolute_expires_at: 1.hour.from_now, contract_epoch: 1,
    ).session
    anchor = RpCoreAppOpSessionBinding.find(session.op_session_binding_id)
    identity = RpCoreAppIdentityBinding.find(anchor.identity_binding_id)
    principal_id = identity.principal_id
    key = OpenSSL::PKey::EC.generate("secp384r1")
    now = Time.current.to_i
    access = JWT.encode(
      { "iss" => issuer,
        "aud" => [cell.client_id],
        "exp" => now + 300,
        "nbf" => now - 5,
        "iat" => now - 5,
        "sub" => identity.subject,
        "sid" => anchor.sid,
        "client_id" => cell.client_id,
        "jti" => "jti-#{suffix}",
        "scope" => "openid",
        "umx_contract_epoch" => 1,
        "authn_ctx" => "normal", },
      key, "ES384", { "kid" => "replica", "typ" => "at+jwt" },
    )
    jwks = OidcOpJwksClient.new(
      jwks_uri: "#{issuer}/.well-known/jwks.json",
      fetcher: -> { { "keys" => [JitSecurityJwtJwk.export_public(key, kid: "replica")] } },
    )
    authenticate =
      -> {
        RpRequestAuthenticator.call(
          cell: cell, access_token: access, local_session_id: session.public_id,
          issuer: issuer, contract_epoch: 1, jwks_client: jwks,
        ).status
      }
    reader_backend = nil
    logout_backend = nil
    statuses = []
    callback_outcome = nil
    RpCoreAppRecord.connected_to(role: :reading) do
      RpCoreAppRecord.cache do
        reader_backend = RpCoreAppRecord.lease_connection.select_value("SELECT pg_backend_pid()")
        statuses << authenticate.call
        logout =
          Thread.new do
            RpCoreAppRecord.connection_pool.with_connection do |connection|
              logout_backend = connection.select_value("SELECT pg_backend_pid()")
              RpCellSessionRevoker.call(
                cell: cell, payload: { "iss" => issuer,
                                       "sid" => anchor.sid,
                                       "jti" => "logout-#{suffix}",
                                       "exp" => now + 300, },
              )
            end
          end

        assert_equal :revoked, Timeout.timeout(10) { logout.value }
        statuses << authenticate.call
        callback_outcome = RpCallbackCommitter.call(
          cell: cell, issuer: issuer, subject: identity.subject, sid: anchor.sid,
          absolute_expires_at: 1.hour.from_now, contract_epoch: 1,
        ).outcome
      end
    end

    assert_not_equal reader_backend, logout_backend
    assert_equal %i(authenticated invalid), statuses
    assert_equal :revoked, callback_outcome
    assert_not RpCoreAppSession.exists?(op_session_binding_id: anchor.id, revoked_at: nil)
  ensure
    if anchor
      RpCoreAppSession.where(op_session_binding_id: anchor.id).delete_all
      RpCoreAppEventReceipt.where(op_session_binding_id: anchor.id).delete_all
      RpCoreAppOpSessionBinding.where(id: anchor.id).delete_all
    end
    RpCoreAppIdentityBinding.where(id: identity.id).delete_all if identity
    RpCoreAppPrincipal.where(id: principal_id).delete_all if principal_id
  end

  test "committed logout before a paused Refresh response prevents late installation on independent connections" do
    cell = RpCellBinding.fetch("rp_core_app")
    issuer = "https://op.example.test"
    suffix = SecureRandom.hex(12)
    session = RpCallbackCommitter.call(
      cell: cell, issuer: issuer, subject: "subject-#{suffix}", sid: "sid-#{suffix}",
      absolute_expires_at: 1.hour.from_now, contract_epoch: 1,
    ).session
    anchor = RpCoreAppOpSessionBinding.find(session.op_session_binding_id)
    identity = RpCoreAppIdentityBinding.find(anchor.identity_binding_id)
    principal_id = identity.principal_id
    key = OpenSSL::PKey::EC.generate("secp384r1")
    now = Time.current.to_i
    access = JWT.encode(
      { "iss" => issuer,
        "aud" => [cell.client_id],
        "exp" => now + 300,
        "nbf" => now - 5,
        "iat" => now - 5,
        "sub" => identity.subject,
        "sid" => anchor.sid,
        "client_id" => cell.client_id,
        "jti" => "jti-#{suffix}",
        "scope" => "openid",
        "umx_contract_epoch" => 1,
        "authn_ctx" => "normal", },
      key, "ES384", { "kid" => "rotation", "typ" => "at+jwt" },
    )
    jwks = OidcOpJwksClient.new(
      jwks_uri: "#{issuer}/.well-known/jwks.json",
      fetcher: -> { { "keys" => [JitSecurityJwtJwk.export_public(key, kid: "rotation")] } },
    )
    dispatched = Queue.new
    deliver = Queue.new
    outcomes = Queue.new
    worker = nil
    token_response = OidcOpTokenClient::Result.new(
      outcome: :success, token_response: { access_token: access, refresh_token: "synthetic-next" }, error: nil,
    )
    OidcOpTokenClient.stub(
      :refresh, ->(**) {
                  dispatched << true
                  deliver.pop
                  token_response
                },
    ) do
      worker =
        Thread.new do
          RpCoreAppRecord.connection_pool.with_connection do |connection|
            outcomes << connection.select_value("SELECT pg_backend_pid()")
            outcomes << RpRefreshCommitter.call(
              cell: cell, local_session_id: session.public_id, refresh_token: "synthetic-predecessor",
              issuer: issuer, contract_epoch: 1, jwks_client: jwks, token_url: "#{issuer}/oauth/token",
              query_url: "#{issuer}/oauth/refresh-deliveries/query",
            )
          end
        rescue StandardError => e
          outcomes << e
        end
      Timeout.timeout(10) { dispatched.pop }
      refresh_backend = outcomes.pop
      logout_backend = RpCoreAppRecord.lease_connection.select_value("SELECT pg_backend_pid()")

      assert_not_equal refresh_backend, logout_backend
      assert_equal :revoked, Timeout.timeout(5) {
        RpCellSessionRevoker.call(
          cell: cell, payload: { "iss" => issuer,
                                 "sid" => anchor.sid,
                                 "jti" => "logout-#{suffix}",
                                 "exp" => now + 300, },
        )
      }
      deliver << true
      Timeout.timeout(10) { worker.join }
      result = outcomes.pop
      raise result if result.is_a?(Exception)

      assert_equal :revoked, result.outcome
      assert_equal 0, session.reload.installed_generation
      assert_nil session.current_access_jti_digest
      assert_not_nil anchor.reload.revoked_at
      assert_equal 1, RpCoreAppEventReceipt.where(op_session_binding_id: anchor.id).count
      assert_nil RpCoreAppRefreshAttempt.find_by!(session_id: session.id).installed_at
    end
  ensure
    deliver << true if deliver
    worker&.join(10)
    if session
      RpCoreAppRefreshAttempt.where(session_id: session.id).delete_all
      RpCoreAppSession.where(id: session.id).delete_all
    end
    if anchor
      RpCoreAppEventReceipt.where(op_session_binding_id: anchor.id).delete_all
      RpCoreAppOpSessionBinding.where(id: anchor.id).delete_all
    end
    RpCoreAppIdentityBinding.where(id: identity.id).delete_all if identity
    RpCoreAppPrincipal.where(id: principal_id).delete_all if principal_id
  end
end
