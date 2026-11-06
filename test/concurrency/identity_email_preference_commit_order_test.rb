# frozen_string_literal: true

require "test_helper"
require "timeout"

class IdentityEmailPreferenceCommitOrderTest < ActiveSupport::TestCase
  self.use_transactional_tests = false
  self.fixture_table_names = []

  test "a failed Zenith preference update preserves the OP authentication event" do
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
    email = ClientEmail.create!(
      user: actor, address: "commit-order-#{SecureRandom.hex(12)}@example.com", confirm_policy: "1",
      user_email_status_id: ClientEmailStatus::VERIFIED,
    )
    email.finalize_binding!
    observed_event = nil
    observer =
      lambda do |_name, _start, _finish, _id, event|
        next unless event.fetch(:sql).match?(/\A\s*UPDATE\s+"client_emails"/i)

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
      assert_raises(IdentityEmailPreferenceCommitter::DependencyFailure) do
        IdentityEmailPreferenceCommitter.call!(
          actor:, token:, email:, preferences: { "promotional" => "0" },
          step_up_evidence: evidence,
        )
      end
    end

    assert observed_event, "a separate OP connection must observe the event when the Zenith write fails"
    assert_predicate email.reload, :promotional?
    assert_equal evidence.jti, grant.reload.oidc_jti
  ensure
    email&.delete
    grant&.delete
    token&.delete
    device&.delete
    actor&.delete
  end

  test "a non-joinable outer OP transaction cannot absorb a Zenith preference commit" do
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
    email = ClientEmail.create!(
      user: actor, address: "savepoint-commit-order-#{SecureRandom.hex(12)}@example.com", confirm_policy: "1",
      user_email_status_id: ClientEmailStatus::VERIFIED,
    )
    email.finalize_binding!
    OpBaseAppRecord.transaction(joinable: false) do
      assert_raises(IdentityEmailPreferenceCommitter::TransactionConflict) do
        IdentityEmailPreferenceCommitter.call!(
          actor:, token:, email:, preferences: { "promotional" => "0" },
          step_up_evidence: evidence,
        )
      end
      raise ActiveRecord::Rollback
    end

    assert_predicate email.reload, :promotional?
    assert_equal evidence.jti, grant.reload.oidc_jti
  ensure
    email&.delete
    grant&.delete
    token&.delete
    device&.delete
    actor&.delete
  end

  test "concurrent use of one Email preference Step-Up changes and audits once" do
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
    email = ClientEmail.create!(
      user: actor, address: "same-proof-#{SecureRandom.hex(12)}@example.com", confirm_policy: "1",
      user_email_status_id: ClientEmailStatus::VERIFIED,
    )
    email.finalize_binding!
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

    ready = Queue.new
    release = Queue.new
    results = Queue.new
    workers =
      2.times.map do
        Thread.new do
          Client.connection_pool.with_connection do
            ready << true
            release.pop
            IdentityEmailPreferenceCommitter.call!(
              actor: Client.find(actor.id), token: ClientToken.find(token.id), email: ClientEmail.find(email.id),
              preferences: { "promotional" => "0" }, step_up_evidence: evidence,
            )
            results << :updated
          rescue IdentityEmailPreferenceCommitter::Denied
            results << :denied
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

    assert_equal [:updated, :updated], outcomes.sort_by(&:to_s)
    assert_not email.reload.promotional?
    assert_equal evidence.jti, grant.reload.oidc_jti
    assert_equal 1, ClientContactAuditOutbox.where(
      event_name: "preferences_changed", owner_ref: actor.public_id, contact_ref: email.public_id,
    ).count
  ensure
    blocker&.exec("ROLLBACK") if blocker && blocker.transaction_status != PG::PQTRANS_IDLE
    blocker&.finish
    probe&.finish
    workers&.each { |worker| worker.join(10) }
    ClientContactAuditOutbox.where(owner_ref: actor.public_id).delete_all if actor&.persisted?
    email&.delete
    grant&.delete
    token&.delete
    device&.delete
    actor&.delete
  end

  test "a lost Zenith commit acknowledgement leaves one committed preference audit and retry is idempotent" do
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
    email = ClientEmail.create!(
      user: actor, address: "lost-ack-#{SecureRandom.hex(12)}@example.com", confirm_policy: "1",
      user_email_status_id: ClientEmailStatus::VERIFIED,
    )
    email.finalize_binding!
    connection = AppZenithRecord.lease_connection
    commit = connection.method(:commit_db_transaction)
    rollback = connection.method(:rollback_db_transaction)
    commit_fired = false
    lose_acknowledgement =
      lambda do
        commit.call
        commit_fired = true
        connection.disconnect!
        raise ActiveRecord::ConnectionNotEstablished, "injected lost Email preference commit acknowledgement"
      end

    assert_raises(IdentityEmailPreferenceCommitter::DependencyFailure) do
      connection.stub(:commit_db_transaction, lose_acknowledgement) do
        connection.stub(:rollback_db_transaction, -> { rollback.call unless commit_fired }) do
          IdentityEmailPreferenceCommitter.call!(
            actor:, token:, email:, preferences: { "promotional" => "0" }, step_up_evidence: evidence,
          )
        end
      end
    end

    assert commit_fired, "the lost-ack fault must run after Zenith commits"
    assert_not ClientEmail.find(email.id).promotional?
    assert_equal evidence.jti, grant.reload.oidc_jti
    assert_equal 1, ClientContactAuditOutbox.where(
      event_name: "preferences_changed", owner_ref: actor.public_id, contact_ref: email.public_id,
    ).count

    retry_result = IdentityEmailPreferenceCommitter.call!(
      actor: Client.find(actor.id), token:, email: ClientEmail.find(email.id),
      preferences: { "promotional" => "0" }, step_up_evidence: evidence,
    )

    assert_not retry_result.promotional?
    assert_equal evidence.jti, grant.reload.oidc_jti
    assert_equal 1, ClientContactAuditOutbox.where(
      event_name: "preferences_changed", owner_ref: actor.public_id, contact_ref: email.public_id,
    ).count
  ensure
    ClientContactAuditOutbox.where(owner_ref: actor.public_id).delete_all if actor&.persisted?
    email&.delete
    grant&.delete
    token&.delete
    device&.delete
    actor&.delete
  end
end
