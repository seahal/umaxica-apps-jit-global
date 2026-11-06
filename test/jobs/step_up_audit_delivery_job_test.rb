# frozen_string_literal: true

require "test_helper"

class StepUpAuditDeliveryJobTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  self.use_transactional_tests = false
  self.fixture_table_names = []

  setup do
    @event_uuids = []
  end

  teardown do
    StepUpAuditOutboxSourcesRegistry::SOURCES.each_value do |model, _realm, attempt_class, _pending_id, _delivered_id|
      outbox_ids = model.where(event_uuid: @event_uuids).select(:id)
      attempt_class.where(outbox_id: outbox_ids).delete_all
      model.where(event_uuid: @event_uuids).delete_all
    end
    Chronicle.where(event_uuid: @event_uuids).delete_all
    clear_enqueued_jobs
  end

  test "writer requires a source transaction and enqueues delivery only after commit" do
    assert_raises(ArgumentError) do
      StepUpAuditOutboxWriter.call(
        source_key: "op_app", event_type: "step_up.requested", realm: "APP", client_id: "base-app-ww",
        subject_ref: "subject-ref", context_ref: PublicId.generate, reason_code: "requested",
        payload: { rp_state_ref: PublicId.generate, return_target_kind: "relative" },
      )
    end

    assert_no_enqueued_jobs only: StepUpAuditDeliveryJob do
      assert_no_difference "ClientStepUpAuditOutbox.count" do
        ClientStepUpAuditOutbox.transaction do
          assert_raises(ArgumentError) do
            StepUpAuditOutboxWriter.call(
              source_key: "op_app", event_type: "step_up.requested", realm: "APP", client_id: "base-app-ww",
              subject_ref: "subject-ref", context_ref: PublicId.generate, reason_code: "requested",
              payload: { rp_state_ref: "short", return_target_kind: "relative" },
            )
          end
        end
      end
    end

    events = []
    assert_enqueued_jobs 4, only: StepUpAuditDeliveryJob do
      StepUpAuditOutboxSourcesRegistry::SOURCES.reject { |key, _| key.start_with?("o9_") }.each do |source_key, source|
        model, realm, _attempt_class, pending_id, _delivered_id = source
        event = nil
        model.transaction do
          event = StepUpAuditOutboxWriter.call(
            source_key:, event_type: "step_up.requested", realm:, client_id: "base-#{realm.downcase}-ww",
            subject_ref: "subject-ref", context_ref: PublicId.generate, reason_code: "requested",
            payload: { rp_state_ref: PublicId.generate, return_target_kind: "relative" },
          )
        end
        events << [event, pending_id]
        @event_uuids << event.event_uuid
      end
    end

    events.each do |event, pending_id|
      assert_equal pending_id, event.delivery_state_id
    end
  end

  test "writer accepts zero-valued audit counters and rejects the nearest negative value" do
    [
      [
        "step_up.committed", "completed",
        { op_context_ref: PublicId.generate, grant_ref: PublicId.generate, verified_method: "passkey", auth_time: -1 },
      ],
      [
        "step_up.installed", "completed",
        { rp_state_ref: PublicId.generate, grant_ref: PublicId.generate, installed_generation: -1 },
      ],
    ].each do |event_type, reason_code, payload|
      assert_raises(ArgumentError) do
        ClientStepUpAuditOutbox.transaction do
          StepUpAuditOutboxWriter.call(
            source_key: "op_app", event_type:, realm: "APP", client_id: "base-app-ww",
            subject_ref: "subject-ref", context_ref: PublicId.generate, reason_code:, payload:,
          )
        end
      end
    end

    events = []
    assert_enqueued_jobs 2, only: StepUpAuditDeliveryJob do
      [
        [
          "step_up.committed", "completed",
          { op_context_ref: PublicId.generate, grant_ref: PublicId.generate, verified_method: "passkey", auth_time: 0 },
        ],
        [
          "step_up.installed", "completed",
          { rp_state_ref: PublicId.generate, grant_ref: PublicId.generate, installed_generation: 0 },
        ],
      ].each do |event_type, reason_code, payload|
        event = nil
        ClientStepUpAuditOutbox.transaction do
          event = StepUpAuditOutboxWriter.call(
            source_key: "op_app", event_type:, realm: "APP", client_id: "base-app-ww",
            subject_ref: "subject-ref", context_ref: PublicId.generate, reason_code:, payload:,
          )
        end
        events << event
        @event_uuids << event.event_uuid
      end
    end

    assert_equal 2, events.length
  end

  test "the recurring sweep delivers a row after its enqueue is lost and repeated delivery is idempotent" do
    event_uuid = SecureRandom.uuid
    @event_uuids << event_uuid
    event = ClientStepUpAuditOutbox.create!(
      event_uuid:, event_type: "step_up.requested", realm: "APP", client_id: "base-app-ww",
      subject_ref: "subject-ref", context_ref: PublicId.generate, reason_code: "requested",
      payload: { rp_state_ref: PublicId.generate, return_target_kind: "relative" },
      occurred_at: ClientStepUpAuditOutbox.database_now,
      delivery_state_id: ClientStepUpAuditOutboxDeliveryState::PENDING,
    )

    assert_enqueued_jobs 0, only: StepUpAuditDeliveryJob do
      StepUpAuditDeliveryJob.perform_now(source_key: "op_app", batch_size: 1)
    end

    assert_equal ClientStepUpAuditOutboxDeliveryState::DELIVERED, event.reload.delivery_state_id
    assert_equal 1, Chronicle.where(event_uuid: event.event_uuid).count
    attempt = ClientStepUpAuditOutboxAttempt.find_by!(outbox_id: event.id)

    assert_equal [1, "delivered", "none"], [attempt.attempt_number, attempt.outcome, attempt.failure_code]

    StepUpAuditDeliveryJob.perform_now(source_key: "op_app", batch_size: 1)

    assert_equal 1, Chronicle.where(event_uuid: event.event_uuid).count
    assert_equal 1, ClientStepUpAuditOutboxAttempt.where(outbox_id: event.id).count
  end

  test "Chronicle commit survives a lost source acknowledgement and a later sweep acknowledges once" do
    event_uuid = SecureRandom.uuid
    @event_uuids << event_uuid
    event = ClientStepUpAuditOutbox.create!(
      event_uuid:, event_type: "step_up.requested", realm: "APP", client_id: "base-app-ww",
      subject_ref: "subject-ref", context_ref: PublicId.generate, reason_code: "requested",
      payload: { rp_state_ref: PublicId.generate, return_target_kind: "relative" },
      occurred_at: ClientStepUpAuditOutbox.database_now,
      delivery_state_id: ClientStepUpAuditOutboxDeliveryState::PENDING,
    )

    ClientStepUpAuditOutbox.transaction(requires_new: true) do
      StepUpAuditDeliveryJob.perform_now(source_key: "op_app", batch_size: 1)

      assert_equal ClientStepUpAuditOutboxDeliveryState::DELIVERED, event.reload.delivery_state_id
      assert_equal 1, Chronicle.where(event_uuid: event.event_uuid).count
      raise ActiveRecord::Rollback
    end

    assert_equal ClientStepUpAuditOutboxDeliveryState::PENDING, event.reload.delivery_state_id
    assert_equal 0, ClientStepUpAuditOutboxAttempt.where(outbox_id: event.id).count
    assert_equal 1, Chronicle.where(event_uuid: event.event_uuid).count

    StepUpAuditDeliveryJob.perform_now(source_key: "op_app", batch_size: 1)

    assert_equal ClientStepUpAuditOutboxDeliveryState::DELIVERED, event.reload.delivery_state_id
    assert_equal 1, Chronicle.where(event_uuid: event.event_uuid).count
    assert_equal 1, ClientStepUpAuditOutboxAttempt.where(outbox_id: event.id, outcome: "delivered").count
  end

  test "concurrent delivery jobs serialize on the outbox row" do
    event_uuid = SecureRandom.uuid
    @event_uuids << event_uuid
    event = ClientStepUpAuditOutbox.create!(
      event_uuid:, event_type: "step_up.requested", realm: "APP", client_id: "base-app-ww",
      subject_ref: "subject-ref", context_ref: PublicId.generate, reason_code: "requested",
      payload: { rp_state_ref: PublicId.generate, return_target_kind: "relative" },
      occurred_at: ClientStepUpAuditOutbox.database_now,
      delivery_state_id: ClientStepUpAuditOutboxDeliveryState::PENDING,
    )
    barrier = Queue.new
    workers =
      2.times.map do
        Thread.new do
          barrier.pop
          StepUpAuditDeliveryJob.perform_now(source_key: "op_app", batch_size: 1)
        end
      end
    2.times { barrier << true }
    workers.each(&:value)

    assert_equal ClientStepUpAuditOutboxDeliveryState::DELIVERED, event.reload.delivery_state_id
    assert_equal 1, Chronicle.where(event_uuid: event.event_uuid).count
    assert_equal 1, ClientStepUpAuditOutboxAttempt.where(outbox_id: event.id, outcome: "delivered").count
  end

  test "retention and result follow each event's explicit mapping" do
    requested_uuid = SecureRandom.uuid
    @event_uuids << requested_uuid
    requested = ClientStepUpAuditOutbox.create!(
      event_uuid: requested_uuid, event_type: "step_up.requested", realm: "APP", client_id: "base-app-ww",
      subject_ref: "subject-ref", context_ref: PublicId.generate, reason_code: "requested",
      payload: { rp_state_ref: PublicId.generate, return_target_kind: "relative" },
      occurred_at: ClientStepUpAuditOutbox.database_now,
      delivery_state_id: ClientStepUpAuditOutboxDeliveryState::PENDING,
    )
    committed_uuid = SecureRandom.uuid
    @event_uuids << committed_uuid
    committed = ClientStepUpAuditOutbox.create!(
      event_uuid: committed_uuid, event_type: "step_up.committed", realm: "APP", client_id: "base-app-ww",
      subject_ref: "subject-ref", context_ref: PublicId.generate, reason_code: "completed",
      payload: {
        op_context_ref: PublicId.generate, grant_ref: PublicId.generate, verified_method: "passkey", auth_time: 1,
      },
      occurred_at: ClientStepUpAuditOutbox.database_now,
      delivery_state_id: ClientStepUpAuditOutboxDeliveryState::PENDING,
    )

    StepUpAuditDeliveryJob.perform_now(source_key: "op_app", batch_size: 2)

    requested_chronicle = Chronicle.find_by!(event_uuid: requested.event_uuid)
    requested_policy_code = ChronicleRetentionPolicy.find(requested_chronicle.chronicle_retention_policy_id).code

    assert_equal ["intent", "security"],
                 [requested_chronicle.result, requested_policy_code]
    assert_equal requested.occurred_at + 365.days, requested_chronicle.erasable_at

    committed_chronicle = Chronicle.find_by!(event_uuid: committed.event_uuid)
    committed_policy_code = ChronicleRetentionPolicy.find(committed_chronicle.chronicle_retention_policy_id).code

    assert_equal ["succeeded", "compliance"],
                 [committed_chronicle.result, committed_policy_code]
  end

  test "an identity conflict remains pending and records only the closed failure code" do
    event_uuid = SecureRandom.uuid
    @event_uuids << event_uuid
    event = ClientStepUpAuditOutbox.create!(
      event_uuid:, event_type: "step_up.requested", realm: "APP", client_id: "base-app-ww",
      subject_ref: "subject-ref", context_ref: PublicId.generate, reason_code: "requested",
      payload: { rp_state_ref: PublicId.generate, return_target_kind: "relative" },
      occurred_at: ClientStepUpAuditOutbox.database_now,
      delivery_state_id: ClientStepUpAuditOutboxDeliveryState::PENDING,
    )
    policy = ChronicleRecordPolicy.retention_policy_for(action: event.event_type)
    Chronicle.create!(
      event_uuid: event.event_uuid, action: event.event_type, result: "failed", reason: "wrong_reason",
      occurred_at: event.occurred_at, metadata: {}, changeset: {}, chronicle_retention_policy: policy,
      erasable_at: ChronicleRecordPolicy.erasable_at_for(policy:, occurred_at: event.occurred_at),
    )

    error =
      assert_raises(StepUpAuditIdentityConflictError) do
        StepUpAuditDeliveryJob.perform_now(source_key: "op_app", batch_size: 1)
      end

    assert_equal "step-up Chronicle event identity conflicts with its source", error.message
    assert_equal ClientStepUpAuditOutboxDeliveryState::PENDING, event.reload.delivery_state_id
    attempt = ClientStepUpAuditOutboxAttempt.find_by!(outbox_id: event.id)

    assert_equal ["failed", "event_identity_conflict"], [attempt.outcome, attempt.failure_code]
  end

  test "delivery covers every OP and RP source and rejects invalid bounds or source keys" do
    events =
      StepUpAuditOutboxSourcesRegistry::SOURCES.reject { |key, _|
        key.start_with?("o9_")
      }.values.map do |model, realm, attempt_class, pending_id, _delivered_id|
        event_uuid = SecureRandom.uuid
        @event_uuids << event_uuid
        model.create!(
          event_uuid:, event_type: "step_up.requested", realm:, client_id: "base-#{realm.downcase}-ww",
          subject_ref: "subject-ref", context_ref: PublicId.generate, reason_code: "requested",
          payload: { rp_state_ref: PublicId.generate, return_target_kind: "relative" },
          occurred_at: model.database_now,
          delivery_state_id: pending_id,
        )
        [model.find_by!(event_uuid: event_uuid), attempt_class]
      end

    StepUpAuditDeliveryJob.perform_now(batch_size: 500)

    events.each do |event, attempt_class|
      assert_equal 1, Chronicle.where(event_uuid: event.event_uuid).count

      assert_equal "delivered", attempt_class.find_by!(outbox_id: event.id).outcome
    end

    [nil, 0, 501, 1.5, "1"].each do |batch_size|
      assert_raises(ArgumentError) { StepUpAuditDeliveryJob.perform_now(batch_size:) }
    end
    assert_raises(ArgumentError) { StepUpAuditDeliveryJob.perform_now(source_key: "unknown") }
  end
end
