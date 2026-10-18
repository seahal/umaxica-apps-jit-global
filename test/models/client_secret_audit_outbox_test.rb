# frozen_string_literal: true

require "test_helper"

class ClientSecretAuditOutboxTest < ActiveSupport::TestCase
  self.fixture_table_names = %w(clients client_statuses client_visibilities client_mfa_levels client_mfa_statuses)

  test "audit actor is the verified request actor rather than the credential owner" do
    actor = clients(:one)
    owner = clients(:two)
    context = ActorValuesContext.empty.with(subject: actor, actor_type: :client, tld: :app, surface: :base)

    event = ClientSecretAuditOutbox.record!(
      actor_context: context, client_ref: owner.public_id, credential_ref: "C" * 21,
      operation_ref: SecureRandom.uuid, occurred_at: Client.database_now, event_name: "secret.renamed",
    )

    event.reload

    assert_equal "Client", event.actor_type
    assert_equal actor.id, event.actor_id
    assert_equal actor.public_id, event.actor_public_ref
    assert_equal owner.public_id, event.client_ref
    assert_nil event.delivered_at
    assert_equal Float::INFINITY, event.purge_eligible_at
  end

  test "autonomous work records execution identity without inventing a human actor" do
    event = ClientSecretAuditOutbox.record!(
      actor_context: ActorValuesContext.empty, client_ref: clients(:one).public_id,
      operation_ref: SecureRandom.uuid, occurred_at: Client.database_now,
      event_name: "secret.discarded", reason: "flow_expired", executor_job_id: SecureRandom.uuid,
    )

    assert_nil event.actor_type
    assert_nil event.actor_id
    assert_nil event.actor_public_ref
    assert_predicate event.executor_job_id, :present?
  end

  test "source transaction rollback also rolls back its audit event" do
    operation = SecureRandom.uuid

    AppZenithRecord.transaction(requires_new: true) do
      ClientSecretIssuance.create!(
        client: clients(:one), origin_operation_id: operation, origin: "passkey_registration",
        attempt_number: 1, browser_session_ref: "server-issued-session", planned_count: 0,
      )
      ClientSecretAuditOutbox.record!(
        actor_context: ActorValuesContext.empty, client_ref: clients(:one).public_id,
        operation_ref: operation, occurred_at: Client.database_now, event_name: "secret.issuance_omitted",
        item_count: 0, reason: "capacity_full",
      )

      assert_equal 1, ClientSecretAuditOutbox.where(operation_ref: operation).count
      raise ActiveRecord::Rollback
    end

    assert_equal 0, ClientSecretAuditOutbox.where(operation_ref: operation).count
    assert_equal 0, ClientSecretIssuance.where(origin_operation_id: operation).count
  end

  test "issuance purge snapshots require one authority reference and remain immutable" do
    actor = clients(:one)
    token = ClientToken.create!(user: actor)
    event = ClientSecretAuditOutbox.record!(
      actor_context: ActorValuesContext.empty, client_ref: actor.public_id,
      operation_ref: SecureRandom.uuid, occurred_at: Client.database_now,
      event_name: "secret.issuance_purged", item_count: 1,
      issuance_origin: "manual", issuance_browser_session_ref: token.public_id,
    )

    assert_raises(ActiveRecord::ReadonlyAttributeError) do
      event.update!(issuance_origin: "passkey_registration")
    end
    assert_raises(ActiveRecord::RecordInvalid) do
      ClientSecretAuditOutbox.record!(
        actor_context: ActorValuesContext.empty, client_ref: actor.public_id,
        operation_ref: SecureRandom.uuid, occurred_at: Client.database_now,
        event_name: "secret.issuance_purged", item_count: 1,
        issuance_origin: "manual",
      )
    end
  end

  test "audit count accepts zero and twenty and rejects adjacent values and wrong types" do
    [0, 20].each do |count|
      event = ClientSecretAuditOutbox.record!(
        actor_context: ActorValuesContext.empty, client_ref: clients(:one).public_id,
        operation_ref: SecureRandom.uuid, occurred_at: Client.database_now,
        event_name: "secret.issuance_omitted", item_count: count,
      )

      assert_equal count, event.item_count
    end
    event = ClientSecretAuditOutbox.record!(
      actor_context: ActorValuesContext.empty, client_ref: clients(:one).public_id,
      operation_ref: SecureRandom.uuid, occurred_at: Client.database_now, event_name: "secret.issuance_omitted",
    )

    assert_nil event.item_count

    [-1, 21].each do |count|
      assert_raises(ActiveRecord::RecordInvalid) do
        ClientSecretAuditOutbox.record!(
          actor_context: ActorValuesContext.empty, client_ref: clients(:one).public_id,
          operation_ref: SecureRandom.uuid, occurred_at: Client.database_now,
          event_name: "secret.issuance_omitted", item_count: count,
        )
      end
    end
    ["0", [], {}, 0.5].each do |count|
      assert_raises(ArgumentError) do
        ClientSecretAuditOutbox.record!(
          actor_context: ActorValuesContext.empty, client_ref: clients(:one).public_id,
          operation_ref: SecureRandom.uuid, occurred_at: Client.database_now,
          event_name: "secret.issuance_omitted", item_count: count,
        )
      end
    end
  end

  test "unknown audit facts and another surface actor are rejected without persistence" do
    count = ClientSecretAuditOutbox.count

    ["raw-secret", "", nil].each do |name|
      assert_raises(ActiveRecord::RecordInvalid) do
        ClientSecretAuditOutbox.record!(
          actor_context: ActorValuesContext.empty, client_ref: clients(:one).public_id,
          operation_ref: SecureRandom.uuid, occurred_at: Client.database_now, event_name: name,
        )
      end
    end
    context = ActorValuesContext.empty.with(actor_type: :operator, tld: :org)
    assert_raises(ArgumentError) do
      ClientSecretAuditOutbox.record!(
        actor_context: context, client_ref: clients(:one).public_id,
        operation_ref: SecureRandom.uuid, occurred_at: Client.database_now, event_name: "secret.claimed",
      )
    end
    assert_equal count, ClientSecretAuditOutbox.count
  end

  test "inconsistent or missing actor contexts cannot silently become anonymous audit actors" do
    contexts = [
      nil,
      ActorValuesContext.empty.with(subject: clients(:one)),
      ActorValuesContext.empty.with(subject: Client.new, actor_type: :client, tld: :app),
    ]

    contexts.each do |context|
      assert_raises(ArgumentError) do
        ClientSecretAuditOutbox.record!(
          actor_context: context, client_ref: clients(:one).public_id,
          operation_ref: SecureRandom.uuid, occurred_at: Client.database_now, event_name: "secret.claimed",
        )
      end
    end
  end
end

class ClientSecretAuditTransactionBoundaryTest < ActiveSupport::TestCase
  self.fixture_table_names = []
  self.use_transactional_tests = false

  test "audit write outside the source transaction is rejected" do
    assert_raises(ArgumentError) do
      ClientSecretAuditOutbox.record!(
        actor_context: ActorValuesContext.empty, client_ref: "C" * 21,
        operation_ref: SecureRandom.uuid, occurred_at: Client.database_now, event_name: "secret.claimed",
      )
    end
  end
end
