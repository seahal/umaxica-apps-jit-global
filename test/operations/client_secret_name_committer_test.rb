# frozen_string_literal: true

require "test_helper"
require "timeout"

class ClientSecretNameCommitterTest < ActiveSupport::TestCase
  # These tests prove the OP/source commit order, so fixture transactions would hide rollback.
  self.use_transactional_tests = false

  setup do
    actor = clients(:one)
    @fixture_actor_ref = actor.public_id
    @fixture_actor_id = actor.id
    @token_snapshots = ClientToken.where(user_id: actor.id).index_by(&:id).transform_values(&:attributes)
    @device_snapshots = ClientDeviceSession.where(user_id: actor.id).index_by(&:id).transform_values(&:attributes)
    @secret_snapshots = ClientSecretCredential.where(client_id: actor.id).index_by(&:id).transform_values(&:attributes)
    @audit_ids = ClientSecretAuditOutbox.where(client_ref: actor.public_id).pluck(:id)
    @step_up_token = client_tokens(:one)
    now = ClientToken.database_now
    @step_up_token.device_session_record!
    @step_up_token.update!(root_login_established_at: now, established_authentication_method: "passkey")
    @step_up_token.rotate_refresh_token!(now:)
    oidc_client = OidcClientRegistry.find!("base-app-ww")
    @step_up_grant = OpAppGrant.create!(
      authentication_epoch: @step_up_token.authentication_epoch, client_token: @step_up_token,
      oidc_client_id: oidc_client.client_id, oidc_scope: "openid profile", oidc_jti: SecureRandom.uuid,
      oidc_nonce: SecureRandom.hex(16), oidc_auth_time: Time.at(now.to_i).utc,
      oidc_acr: StepUpEvidenceResolver::STEP_UP_ACR, oidc_amr: JSON.generate(["passkey"]),
      refresh_token_expires_at: now + 1.hour,
    )
    @step_up_grant.issue_refresh_token!(now:)
    @step_up_evidence = StepUpEvidenceValue.new(
      acr: @step_up_grant.oidc_acr, amr: ["passkey"], auth_time: now.to_i, sid: @step_up_grant.public_id,
      sub: OidcSubject.for(actor, resource_type: "client"), client_id: oidc_client.client_id,
      aud: [oidc_client.aud], jti: @step_up_grant.oidc_jti,
    )
  end

  teardown do
    OpAppGrant.where(id: @step_up_grant.id).delete_all
    ClientSecretAuditOutbox.where(client_ref: @fixture_actor_ref).where.not(id: @audit_ids).delete_all
    @device_snapshots.each do |id, attributes|
      ClientDeviceSession.where(id: id).update_all(attributes.except("id"))
    end
    extra_token_ids = ClientToken.where(user_id: @fixture_actor_id).where.not(id: @token_snapshots.keys).pluck(:id)
    ClientToken.where(id: extra_token_ids).delete_all
    @token_snapshots.each do |id, attributes|
      ClientToken.where(id: id).update_all(attributes.except("id"))
    end
    @secret_snapshots.each do |id, attributes|
      ClientSecretCredential.where(id: id).update_all(attributes.except("id"))
    end
  end

  test "session revocation restriction and expiry are reread instead of trusting the supplied token" do
    actor = clients(:one)
    token = client_tokens(:one)
    context = ActorValuesContext.empty.with(subject: actor, actor_type: :client, tld: :app, surface: :base)
    credential = client_secret_credentials(:one)
    states = [
      { user_token_status_id: ClientTokenStatus::REVOKED },
      { user_token_status_id: ClientTokenStatus::RESTRICTED },
      { discard_at: ClientToken.database_now - 1.second },
    ]
    original = token.reload.attributes.except("id")
    states.each do |state|
      ClientToken.where(id: token.id).update_all(state)
      assert_no_difference("ClientSecretAuditOutbox.count") do
        assert_raises(ClientSecretNameCommitter::Denied) do
          ClientSecretNameCommitter.call!(
            actor_context: context, token: token, credential: credential, name: "Rejected",
            step_up_evidence: @step_up_evidence,
          )
        end
      end
      assert_equal "Fixture Secret 1", credential.reload.name
      ClientToken.where(id: token.id).update_all(original)
    end
  end

  test "claimed revoked discarded and unconfirmed credentials cannot be renamed or revived" do
    actor = clients(:one)
    token = client_tokens(:one)
    context = ActorValuesContext.empty.with(subject: actor, actor_type: :client, tld: :app, surface: :base)
    credential = client_secret_credentials(:one)
    now = Client.database_now
    states = [
      { claimed_at: now,
        claim_operation_id: SecureRandom.uuid,
        claim_sign_in_flow_ref: "claimed-test-flow",
        claim_ceremony_session_id: 1, },
      { revoked_at: now },
      { discard_at: now },
      { confirmed_at: nil },
    ]
    states.each do |state|
      ClientSecretCredential.transaction(requires_new: true) do
        # Persist lifecycle facts to exercise the public operation against actual DB rows.
        ClientSecretCredential.where(id: credential.id).update_all(state)
        assert_no_difference("ClientSecretAuditOutbox.count") do
          assert_raises(ClientSecretNameCommitter::Denied) do
            ClientSecretNameCommitter.call!(
              actor_context: context, token: token, credential: credential, name: "Rejected",
              step_up_evidence: @step_up_evidence,
            )
          end
        end
        assert_equal "Fixture Secret 1", credential.reload.name
        state.each do |column, value|
          if value.nil?
            assert_nil credential[column]
          else
            assert_equal value, credential[column]
          end
        end
        raise ActiveRecord::Rollback
      end
    end
  end

  test "foreign grant and altered event evidence cannot rename a credential" do
    actor = clients(:one)
    token = client_tokens(:one)
    credential = client_secret_credentials(:one)
    context = ActorValuesContext.empty.with(subject: actor, actor_type: :client, tld: :app, surface: :base)
    evidence = @step_up_evidence
    [evidence.with(sid: "foreign-grant"), evidence.with(jti: SecureRandom.uuid)].each do |candidate_evidence|
      assert_no_difference("ClientSecretAuditOutbox.count") do
        assert_raises(ClientSecretNameCommitter::Denied) do
          ClientSecretNameCommitter.call!(
            actor_context: context, token:, credential:, name: "Wrong", step_up_evidence: candidate_evidence,
          )
        end
      end
      assert_equal "Fixture Secret 1", credential.reload.name
    end
  end

  test "a superseded device token cannot authorize a Secret rename" do
    actor = clients(:one)
    token = client_tokens(:one)
    credential = client_secret_credentials(:one)
    context = ActorValuesContext.empty.with(subject: actor, actor_type: :client, tld: :app, surface: :base)
    evidence = @step_up_evidence
    device = token.device_session_record!
    replacement = ClientToken.create!(authentication_epoch: 0, user: actor, device_session: device)
    device.update!(current_refresh_token_id: replacement.id)

    assert_raises(ClientSecretNameCommitter::Denied) do
      ClientSecretNameCommitter.call!(
        actor_context: context, token:, credential:, name: "Denied", step_up_evidence: evidence,
      )
    end
    assert_equal "Fixture Secret 1", credential.reload.name
  end

  test "a revoked device cannot authorize a Secret rename" do
    actor = clients(:one)
    token = client_tokens(:one)
    credential = client_secret_credentials(:one)
    context = ActorValuesContext.empty.with(subject: actor, actor_type: :client, tld: :app, surface: :base)
    evidence = @step_up_evidence
    token.device_session_record!.revoke!

    assert_raises(ClientSecretNameCommitter::Denied) do
      ClientSecretNameCommitter.call!(
        actor_context: context, token:, credential:, name: "Denied", step_up_evidence: evidence,
      )
    end
    assert_equal "Fixture Secret 1", credential.reload.name
  end

  test "altered OP event is refused before the Secret name and audit are written" do
    actor = clients(:one)
    token = client_tokens(:one)
    credential = client_secret_credentials(:one)
    context = ActorValuesContext.empty.with(subject: actor, actor_type: :client, tld: :app, surface: :base)
    evidence = @step_up_evidence.with(jti: SecureRandom.uuid)

    assert_raises(ClientSecretNameCommitter::Denied) do
      ClientSecretNameCommitter.call!(
        actor_context: context, token:, credential:, name: "New", step_up_evidence: evidence,
      )
    end
    assert_equal "Fixture Secret 1", credential.reload.name
    assert_equal 0, ClientSecretAuditOutbox.where(
      event_name: "secret.renamed", credential_ref: credential.public_id,
    ).where.not(id: @audit_ids).count
  end

  test "Zenith write failure leaves the Step-Up event available and the name and audit unchanged" do
    actor = clients(:one)
    token = client_tokens(:one)
    credential = client_secret_credentials(:one)
    context = ActorValuesContext.empty.with(subject: actor, actor_type: :client, tld: :app, surface: :base)
    evidence = @step_up_evidence
    failed = false
    observer =
      lambda do |_name, _start, _finish, _id, event|
        next unless event.fetch(:sql).match?(/\A\s*UPDATE\s+"client_secret_credentials"/i)

        failed = true
        raise ActiveRecord::ConnectionNotEstablished, "injected Zenith write failure"
      end

    ActiveSupport::Notifications.subscribed(observer, "sql.active_record") do
      assert_raises(ClientSecretNameCommitter::DependencyFailure) do
        ClientSecretNameCommitter.call!(
          actor_context: context, token:, credential:, name: "New", step_up_evidence: evidence,
        )
      end
    end

    assert failed
    assert_equal "Fixture Secret 1", credential.reload.name
    assert_equal 0,
                 ClientSecretAuditOutbox.where(event_name: "secret.renamed", credential_ref: credential.public_id)
                   .where.not(id: @audit_ids).count
    assert OpAppGrant.exists?(public_id: evidence.sid)
  end

  test "Zenith commit failure leaves the Step-Up event available and rolls back the name and audit" do
    actor = clients(:one)
    token = client_tokens(:one)
    credential = client_secret_credentials(:one)
    context = ActorValuesContext.empty.with(subject: actor, actor_type: :client, tld: :app, surface: :base)
    evidence = @step_up_evidence
    failed_commit = -> { raise ActiveRecord::ConnectionNotEstablished, "injected Secret Zenith commit failure" }

    assert_raises(ClientSecretNameCommitter::DependencyFailure) do
      AppZenithRecord.lease_connection.stub(:commit_db_transaction, failed_commit) do
        ClientSecretNameCommitter.call!(
          actor_context: context, token:, credential:, name: "Commit failure", step_up_evidence: evidence,
        )
      end
    end

    assert_equal "Fixture Secret 1", credential.reload.name
    assert_equal 0,
                 ClientSecretAuditOutbox.where(event_name: "secret.renamed", credential_ref: credential.public_id)
                   .where.not(id: @audit_ids).count
    assert OpAppGrant.exists?(public_id: evidence.sid)
  end

  test "a lost Zenith commit acknowledgement returns dependency failure after the rename commits" do
    actor = clients(:one)
    token = client_tokens(:one)
    credential = client_secret_credentials(:one)
    context = ActorValuesContext.empty.with(subject: actor, actor_type: :client, tld: :app, surface: :base)
    evidence = @step_up_evidence
    connection = AppZenithRecord.lease_connection
    commit = connection.method(:commit_db_transaction)
    lose_acknowledgement =
      lambda do
        commit.call
        connection.disconnect!
        raise ActiveRecord::ConnectionNotEstablished, "injected lost Secret Zenith commit acknowledgement"
      end

    assert_raises(ClientSecretNameCommitter::DependencyFailure) do
      connection.stub(:commit_db_transaction, lose_acknowledgement) do
        connection.stub(:rollback_db_transaction, -> { }) do
          ClientSecretNameCommitter.call!(
            actor_context: context, token:, credential:, name: "Commit acknowledgement lost",
            step_up_evidence: evidence,
          )
        end
      end
    end

    assert_equal "Commit acknowledgement lost", credential.reload.name
    assert OpAppGrant.exists?(public_id: evidence.sid)
    assert_equal 1, ClientSecretAuditOutbox.where(
      client_ref: actor.public_id, credential_ref: credential.public_id, event_name: "secret.renamed",
    ).where.not(id: @audit_ids).count
  end

  test "source rollback discards both the name change and its outbox event" do
    actor = clients(:one)
    token = client_tokens(:one)
    evidence = @step_up_evidence
    context = ActorValuesContext.empty.with(subject: actor, actor_type: :client, tld: :app, surface: :base)
    credential = client_secret_credentials(:one)

    assert_no_difference("ClientSecretAuditOutbox.count") do
      Client.transaction(requires_new: true) do
        ClientSecretNameCommitter.call!(
          actor_context: context, token:, credential:, name: "Rolled back", step_up_evidence: evidence,
        )

        assert_equal "Rolled back", credential.reload.name
        assert_equal 1, ClientSecretAuditOutbox.where(
          event_name: "secret.renamed", credential_ref: credential.public_id,
        ).count
        raise ActiveRecord::Rollback
      end
    end
    assert_equal "Fixture Secret 1", credential.reload.name
  end

  test "name boundaries 254 and 255 succeed while 256 and input sentinels leave no mutation" do
    actor = clients(:one)
    token = client_tokens(:one)
    evidence = @step_up_evidence
    context = ActorValuesContext.empty.with(subject: actor, actor_type: :client, tld: :app, surface: :base)
    credential = client_secret_credentials(:one)
    [254, 255].each do |length|
      assert_difference("ClientSecretAuditOutbox.count", 1) do
        ClientSecretNameCommitter.call!(
          actor_context: context, token:, credential:, name: "n" * length, step_up_evidence: evidence,
        )
      end
      assert_equal length, credential.reload.name.length
    end

    ["n" * 256, nil, "", " ", 0, [], {}, "n\0", "\xFF".b.force_encoding("UTF-8")].each do |name|
      assert_no_difference("ClientSecretAuditOutbox.count") do
        assert_raises(ClientSecretNameCommitter::InvalidName) do
          ClientSecretNameCommitter.call!(
            actor_context: context, token:, credential:, name:, step_up_evidence: evidence,
          )
        end
      end
      assert_equal "n" * 255, credential.reload.name
    end
  end

  test "the same current Step-Up event authorizes repeated renames" do
    actor = clients(:one)
    token = client_tokens(:one)
    evidence = @step_up_evidence
    context = ActorValuesContext.empty.with(subject: actor, actor_type: :client, tld: :app, surface: :base)
    credential = client_secret_credentials(:one)

    ClientSecretNameCommitter.call!(
      actor_context: context, token:, credential:, name: "First", step_up_evidence: evidence,
    )
    ClientSecretNameCommitter.call!(
      actor_context: context, token:, credential:, name: "Second", step_up_evidence: evidence,
    )

    assert_equal "Second", credential.reload.name
    assert_equal 2, ClientSecretAuditOutbox.where(
      event_name: "secret.renamed", credential_ref: credential.public_id,
    ).where.not(id: @audit_ids).count
  end

  test "concurrent use of one Step-Up event authorizes both serialized renames" do
    actor_id = @fixture_actor_id
    actor = Client.find(actor_id)
    token = ClientToken.find_by!(user_id: actor_id, public_id: client_tokens(:one).public_id)
    evidence = @step_up_evidence
    credential = client_secret_credentials(:one)
    database = AppZenithRecord.connection_db_config.configuration_hash
    blocker = PG.connect(
      host: database.fetch(:host), port: database.fetch(:port), dbname: database.fetch(:database),
      user: database.fetch(:username), password: database.fetch(:password),
    )
    probe = PG.connect(
      host: database.fetch(:host), port: database.fetch(:port), dbname: database.fetch(:database),
      user: database.fetch(:username), password: database.fetch(:password),
    )
    blocker.exec("BEGIN")
    blocker.exec_params("SELECT id FROM clients WHERE id = $1 FOR UPDATE", [actor_id])

    names = ["Concurrent rename one", "Concurrent rename two"]
    ready = Queue.new
    release = Queue.new
    results = Queue.new
    workers =
      names.map do |name|
        Thread.new do
          AppZenithRecord.connection_pool.with_connection do
            ready << true
            release.pop
            current_actor = Client.find(actor_id)
            context = ActorValuesContext.empty.with(
              subject: current_actor, actor_type: :client, tld: :app, surface: :base,
            )
            ClientSecretNameCommitter.call!(
              actor_context: context, token: ClientToken.find(token.id),
              credential: ClientSecretCredential.find(credential.id), name:, step_up_evidence: evidence,
            )
            results << [:renamed, name]
          rescue ClientSecretNameCommitter::Denied
            results << [:denied, name]
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
    assert_includes names, credential.reload.name
    assert_equal 2, ClientSecretAuditOutbox.where(
      event_name: "secret.renamed", client_ref: actor.public_id, credential_ref: credential.public_id,
    ).where.not(id: @audit_ids).count
  ensure
    2.times { release << true } if release
    blocker&.exec("ROLLBACK") if blocker && blocker.transaction_status != PG::PQTRANS_IDLE
    blocker&.finish
    probe&.finish
    workers&.each { |worker| worker.join(10) }
  end

  test "malformed and expired OP event values refuse rename" do
    actor = clients(:one)
    token = client_tokens(:one)
    evidence = @step_up_evidence
    context = ActorValuesContext.empty.with(subject: actor, actor_type: :client, tld: :app, surface: :base)
    credential = client_secret_credentials(:one)
    now = ClientToken.database_now.to_i
    invalid_evidence = [
      evidence.with(sid: "foreign-grant"),
      evidence.with(jti: SecureRandom.uuid),
      evidence.with(sub: "foreign-subject"),
      evidence.with(client_id: "foreign-client"),
      evidence.with(aud: ["foreign-audience"]),
      evidence.with(acr: "urn:example:wrong"),
      evidence.with(auth_time: now - 301),
      evidence.with(auth_time: now + 60),
    ]
    invalid_evidence.each do |candidate_evidence|
      assert_no_difference("ClientSecretAuditOutbox.count") do
        assert_raises(ClientSecretNameCommitter::Denied) do
          ClientSecretNameCommitter.call!(
            actor_context: context, token:, credential:, name: "Rejected", step_up_evidence: candidate_evidence,
          )
        end
      end
      assert_equal "Fixture Secret 1", credential.reload.name
    end
  end

  test "owner with current Step-Up evidence renames only metadata and commits one source event" do
    actor = clients(:one)
    token = client_tokens(:one)
    evidence = @step_up_evidence
    credential = client_secret_credentials(:one)
    original_digest = credential.password_digest
    context = ActorValuesContext.empty.with(subject: actor, actor_type: :client, tld: :app, surface: :base)

    ClientSecretNameCommitter.call!(
      actor_context: context, token:, credential:, name: "Personal label", step_up_evidence: evidence,
    )

    assert_equal "Personal label", credential.reload.name
    assert_equal original_digest, credential.password_digest
    assert_nil credential.claimed_at
    event = ClientSecretAuditOutbox.find_by!(event_name: "secret.renamed", credential_ref: credential.public_id)

    assert_equal actor.public_id, event.actor_public_ref
    assert_equal actor.public_id, event.client_ref
    assert_nil event.reason
    assert_nil event.delivered_at
  end

  test "an enclosing OP transaction is refused before evidence or source writes" do
    actor = clients(:one)
    token = client_tokens(:one)
    evidence = @step_up_evidence
    credential = client_secret_credentials(:one)
    context = ActorValuesContext.empty.with(subject: actor, actor_type: :client, tld: :app, surface: :base)
    token_before = token.reload.attributes

    OpBaseAppRecord.transaction(joinable: false) do
      assert_no_difference("ClientSecretAuditOutbox.count") do
        assert_raises(ClientSecretNameCommitter::TransactionConflict) do
          ClientSecretNameCommitter.call!(
            actor_context: context, token:, credential:, name: "Enclosing transaction", step_up_evidence: evidence,
          )
        end
      end
    end

    assert_equal "Fixture Secret 1", credential.reload.name
    assert_equal token_before, token.reload.attributes
    assert OpAppGrant.exists?(public_id: evidence.sid)
  end

  test "missing Step-Up cannot rename and creates no source event" do
    actor = clients(:one)
    token = client_tokens(:one)
    credential = client_secret_credentials(:one)
    context = ActorValuesContext.empty.with(subject: actor, actor_type: :client, tld: :app, surface: :base)

    assert_no_difference("ClientSecretAuditOutbox.count") do
      assert_raises(ClientSecretNameCommitter::Denied) do
        ClientSecretNameCommitter.call!(actor_context: context, token:, credential:, name: "Rejected")
      end
    end
    assert_equal "Fixture Secret 1", credential.reload.name
  end

  test "another owner's credential is refused even with valid Step-Up evidence" do
    actor = clients(:one)
    token = client_tokens(:one)
    context = ActorValuesContext.empty.with(subject: actor, actor_type: :client, tld: :app, surface: :base)
    credential = client_secret_credentials(:two)

    assert_no_difference("ClientSecretAuditOutbox.count") do
      assert_raises(ClientSecretNameCommitter::Denied) do
        ClientSecretNameCommitter.call!(
          actor_context: context, token:, credential:, name: "Rejected",
          step_up_evidence: @step_up_evidence,
        )
      end
    end
    assert_equal "Fixture Secret 2", credential.reload.name
  end
end
