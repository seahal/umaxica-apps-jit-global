# frozen_string_literal: true

require "test_helper"
require "timeout"

class IdentityTotpNameCommitOrderTest < ActiveSupport::TestCase
  self.use_transactional_tests = false
  self.fixture_table_names = []

  %w(joined savepoint).each do |nesting|
    test "an outer OP #{nesting} transaction cannot authorize a TOTP rename" do
      actor = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE)
      token = ClientToken.create!(authentication_epoch: 0, user: actor)
      evidence_now = OpBaseAppRecord.database_now
      token.update!(root_login_established_at: evidence_now, established_authentication_method: "passkey")
      token.rotate_refresh_token!(now: evidence_now)
      device = token.device_session_record!
      oidc_client = OidcClientRegistry.find!("base-app-ww")
      grant = OpAppGrant.create!(
        authentication_epoch: token.authentication_epoch, client_token: token, oidc_client_id: oidc_client.client_id,
        oidc_scope: "openid profile", oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16),
        oidc_auth_time: Time.at(evidence_now.to_i).utc, oidc_acr: StepUpEvidenceResolver::STEP_UP_ACR,
        oidc_amr: JSON.generate(["passkey"]), refresh_token_expires_at: evidence_now + 1.hour,
      )
      grant.issue_refresh_token!(now: evidence_now)
      evidence = StepUpEvidenceValue.new(
        acr: grant.oidc_acr, amr: ["passkey"], auth_time: evidence_now.to_i, sid: grant.public_id,
        sub: OidcSubject.for(actor, resource_type: "client"), client_id: oidc_client.client_id,
        aud: [oidc_client.aud], jti: grant.oidc_jti,
      )
      credential = ClientTotpCredential.create_for_user!(
        user: actor, private_key: ROTP::Base32.random_base32,
        user_totp_credential_status_id: ClientTotpCredentialStatus::ACTIVE,
      )
      evidence_jti = grant.reload.oidc_jti
      OpBaseAppRecord.transaction do
        OpBaseAppRecord.transaction(requires_new: nesting == "savepoint") do
          assert_raises(IdentityTotpNameCommitter::DependencyFailure) do
            IdentityTotpNameCommitter.call!(actor:, token:, credential:, title: "New title", step_up_evidence: evidence)
          end
        end
        raise ActiveRecord::Rollback
      end

      assert_nil credential.reload.title
      assert_equal evidence_jti, grant.reload.oidc_jti
    ensure
      credential&.delete
      grant&.delete
      token&.delete
      device&.delete
      actor&.delete
    end
  end

  test "a failed Zenith TOTP rename preserves the OP authentication event" do
    actor = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE)
    token = ClientToken.create!(authentication_epoch: 0, user: actor)
    evidence_now = OpBaseAppRecord.database_now
    token.update!(root_login_established_at: evidence_now, established_authentication_method: "passkey")
    token.rotate_refresh_token!(now: evidence_now)
    device = token.device_session_record!
    oidc_client = OidcClientRegistry.find!("base-app-ww")
    grant = OpAppGrant.create!(
      authentication_epoch: token.authentication_epoch, client_token: token, oidc_client_id: oidc_client.client_id,
      oidc_scope: "openid profile", oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16),
      oidc_auth_time: Time.at(evidence_now.to_i).utc, oidc_acr: StepUpEvidenceResolver::STEP_UP_ACR,
      oidc_amr: JSON.generate(["passkey"]), refresh_token_expires_at: evidence_now + 1.hour,
    )
    grant.issue_refresh_token!(now: evidence_now)
    evidence = StepUpEvidenceValue.new(
      acr: grant.oidc_acr, amr: ["passkey"], auth_time: evidence_now.to_i, sid: grant.public_id,
      sub: OidcSubject.for(actor, resource_type: "client"), client_id: oidc_client.client_id,
      aud: [oidc_client.aud], jti: grant.oidc_jti,
    )
    credential = ClientTotpCredential.create_for_user!(
      user: actor, private_key: ROTP::Base32.random_base32,
      user_totp_credential_status_id: ClientTotpCredentialStatus::ACTIVE,
    )
    observed_event = nil
    observer =
      lambda do |_name, _start, _finish, _id, event|
        next unless event.fetch(:sql).match?(/\A\s*UPDATE\s+"client_totp_credentials"/i)

        reader =
          Thread.new do
            OpAppGrant.connection_pool.with_connection do
              OpAppGrant.find(grant.id).oidc_jti == evidence.jti
            end
          end
        observed_event = Timeout.timeout(10) { reader.value }
        raise ActiveRecord::ConnectionNotEstablished, "injected Zenith write failure"
      end

    ActiveSupport::Notifications.subscribed(observer, "sql.active_record") do
      assert_raises(IdentityTotpNameCommitter::DependencyFailure) do
        IdentityTotpNameCommitter.call!(actor:, token:, credential:, title: "New title", step_up_evidence: evidence)
      end
    end

    assert observed_event, "a separate OP connection must observe the event when Zenith fails"
    assert_nil credential.reload.title
    assert_equal evidence.jti, grant.reload.oidc_jti
  ensure
    credential&.delete
    grant&.delete
    token&.delete
    device&.delete
    actor&.delete
  end

  test "concurrent TOTP renames can reuse one Step-Up event" do
    actor = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE)
    token = ClientToken.create!(authentication_epoch: 0, user: actor)
    evidence_now = OpBaseAppRecord.database_now
    token.update!(root_login_established_at: evidence_now, established_authentication_method: "passkey")
    token.rotate_refresh_token!(now: evidence_now)
    device = token.device_session_record!
    oidc_client = OidcClientRegistry.find!("base-app-ww")
    grant = OpAppGrant.create!(
      authentication_epoch: token.authentication_epoch, client_token: token, oidc_client_id: oidc_client.client_id,
      oidc_scope: "openid profile", oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16),
      oidc_auth_time: Time.at(evidence_now.to_i).utc, oidc_acr: StepUpEvidenceResolver::STEP_UP_ACR,
      oidc_amr: JSON.generate(["passkey"]), refresh_token_expires_at: evidence_now + 1.hour,
    )
    grant.issue_refresh_token!(now: evidence_now)
    evidence = StepUpEvidenceValue.new(
      acr: grant.oidc_acr, amr: ["passkey"], auth_time: evidence_now.to_i, sid: grant.public_id,
      sub: OidcSubject.for(actor, resource_type: "client"), client_id: oidc_client.client_id,
      aud: [oidc_client.aud], jti: grant.oidc_jti,
    )
    credential = ClientTotpCredential.create_for_user!(
      user: actor, private_key: ROTP::Base32.random_base32,
      user_totp_credential_status_id: ClientTotpCredentialStatus::ACTIVE,
    )
    database = Client.connection_db_config.configuration_hash
    blocker = PG.connect(
      host: database.fetch(:host), port: database.fetch(:port), dbname: database.fetch(:database),
      user: database.fetch(:username), password: database.fetch(:password),
    )
    probe = PG.connect(
      host: database.fetch(:host), port: database.fetch(:port), dbname: database.fetch(:database),
      user: database.fetch(:username), password: database.fetch(:password),
    )
    blocker.exec("BEGIN")
    blocker.exec_params("SELECT id FROM clients WHERE id = $1 FOR UPDATE", [actor.id])

    titles = ["Concurrent TOTP title one", "Concurrent TOTP title two"]
    ready = Queue.new
    release = Queue.new
    results = Queue.new
    workers =
      titles.map do |title|
        Thread.new do
          Client.connection_pool.with_connection do
            ready << true
            release.pop
            IdentityTotpNameCommitter.call!(
              actor: Client.find(actor.id), token: ClientToken.find(token.id),
              credential: ClientTotpCredential.find(credential.id), title: title, step_up_evidence: evidence,
            )
            results << [:renamed, title]
          rescue IdentityTotpNameCommitter::Denied
            results << [:denied, title]
          rescue StandardError => e
            results << e
          end
        end
      end

    2.times { Timeout.timeout(8) { ready.pop } }
    2.times { release << true }
    Timeout.timeout(10) do
      loop do
        waiting = probe.exec(<<~SQL.squish).getvalue(0, 0).to_i
          SELECT count(*) FROM pg_stat_activity
          WHERE datname = current_database()
            AND wait_event_type = 'Lock'
            AND query LIKE '%FROM "clients"%'
            AND query LIKE '%FOR UPDATE%'
        SQL
        break if waiting >= 2

        Thread.pass
      end
    end

    blocker.exec("COMMIT")
    outcomes = 2.times.map { Timeout.timeout(10) { results.pop } }
    outcomes.each { |outcome| raise outcome if outcome.is_a?(Exception) }

    assert_equal 2, outcomes.count { |outcome| outcome.first == :renamed }
    assert_equal 0, outcomes.count { |outcome| outcome.first == :denied }
    assert_includes titles, credential.reload.title
    assert_equal evidence.jti, grant.reload.oidc_jti
  ensure
    2.times { release << true } if release
    blocker&.exec("ROLLBACK") if blocker && blocker.transaction_status != PG::PQTRANS_IDLE
    blocker&.finish
    probe&.finish
    workers&.each { |worker| worker.join(10) }
    credential&.delete
    grant&.delete
    token&.delete
    device&.delete
    actor&.delete
  end
end
