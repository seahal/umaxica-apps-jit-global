# frozen_string_literal: true

require "test_helper"

class PasskeyAuditDeliveryJobTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  setup do
    ChronicleRetentionPolicy.find_or_create_by!(code: "security") do |policy|
      policy.name = "Security"
      policy.duration_days = 365
      policy.permanent = false
    end
  end

  test "delivers a principal outbox event once and preserves its UUID" do
    actor = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL)
    passkey = PasskeyRegistrationOperation.call!(
      actor: actor,
      passkey_class: ClientPasskey,
      attributes: {
        webauthn_id: "delivery-webauthn-#{SecureRandom.uuid}",
        public_key: "delivery-public-key",
        description: "Delivery key",
      },
      audit: {
        event_type: "passkey.registered.settings",
        surface: "app",
        actor_ref: actor.public_id,
        operation_ref: SecureRandom.uuid,
        metadata: { reason_code: "settings_registration" },
      },
    )
    event = ClientPasskeyAuditOutbox.find_by!(external_id: passkey.external_id)

    assert_difference -> { Chronicle.where(event_uuid: event.event_uuid).count }, 1 do
      PasskeyAuditDeliveryJob.perform_now
    end
    assert event.reload.acknowledged_at
    chronicle = Chronicle.find_by!(event_uuid: event.event_uuid)

    assert_equal event.event_type, chronicle.action
    assert_equal event.occurred_at, chronicle.occurred_at
    assert_equal event.operation_ref, chronicle.request_id
    assert_equal passkey.external_id.to_s, chronicle.metadata.fetch("external_id")
    assert_equal "app", chronicle.metadata.fetch("surface")
    assert_equal "settings_registration", chronicle.metadata.fetch("reason_code")

    assert_no_difference -> { Chronicle.where(event_uuid: event.event_uuid).count } do
      PasskeyAuditDeliveryJob.perform_now
    end
  end

  test "rejects an unbounded delivery batch before changing source rows" do
    [nil, 0, 501, "1"].each do |batch_size|
      assert_raises(ArgumentError) { PasskeyAuditDeliveryJob.perform_now(batch_size:) }
    end
  end

  test "continues after one event fails and leaves it retryable" do
    actor = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL)
    first = register_passkey(actor, "first")
    second = register_passkey(actor, "second")
    first_event = ClientPasskeyAuditOutbox.find_by!(external_id: first.external_id)
    second_event = ClientPasskeyAuditOutbox.find_by!(external_id: second.external_id)

    Chronicle.create!(
      event_uuid: first_event.event_uuid,
      action: "passkey.description_changed",
      result: "succeeded",
      occurred_at: first_event.occurred_at,
      request_id: first_event.operation_ref,
      metadata: { "surface" => "app", "external_id" => first.external_id.to_s },
      changeset: {},
      chronicle_retention_policy: ChronicleRecordPolicy.retention_policy_for(
        action: first_event.event_type,
      ),
      erasable_at: ChronicleRecordPolicy.erasable_at_for(
        policy: ChronicleRecordPolicy.retention_policy_for(action: first_event.event_type),
        occurred_at: first_event.occurred_at,
      ),
    )

    error = assert_raises(ArgumentError) { PasskeyAuditDeliveryJob.perform_now }
    assert_equal "Passkey Chronicle event identity conflicts with its source", error.message
    assert_nil first_event.reload.acknowledged_at
    assert second_event.reload.acknowledged_at
    assert Chronicle.exists?(event_uuid: second_event.event_uuid)
  end

  test "delivery after credential deletion preserves system actor and original occurrence time" do
    actor = Visitor.create!(security_mode_id: SecurityModeConfigurable::NORMAL)
    passkey = PasskeyRegistrationOperation.call!(
      actor: actor, passkey_class: VisitorPasskey,
      attributes: { webauthn_id: SecureRandom.uuid, public_key: "system-purge-key" },
    )
    external_id = passkey.external_id
    occurred_at = VisitorPasskey.database_now - 1.hour
    event = nil
    VisitorPasskey.transaction do
      event = PasskeyAuditOutbox.record_for!(
        passkey: passkey, event_type: "passkey.purged", surface: "com",
        actor_ref: nil, occurred_at: occurred_at,
      )
      passkey.destroy!
    end

    PasskeyAuditDeliveryJob.perform_now

    audit = Chronicle.find_by!(event_uuid: event.event_uuid)

    assert_not VisitorPasskey.exists?(external_id: external_id)
    assert_equal external_id, audit.metadata.fetch("external_id")
    assert_equal "com", audit.metadata.fetch("surface")
    assert_not audit.metadata.key?("actor_ref")
    assert_equal event.occurred_at, audit.occurred_at
    assert event.reload.acknowledged_at
  end

  test "retry after Chronicle commit before acknowledgement converges to one event" do
    actor = Operator.create!(security_mode_id: SecurityModeConfigurable::ADVANCED)
    passkey = PasskeyRegistrationOperation.call!(
      actor: actor, passkey_class: OperatorPasskey,
      attributes: { webauthn_id: SecureRandom.uuid, public_key: "retry-key" },
      audit: { event_type: "passkey.registered.settings", surface: "org" },
    )
    event = OperatorPasskeyAuditOutbox.find_by!(external_id: passkey.external_id)
    policy = ChronicleRecordPolicy.retention_policy_for(action: event.event_type)
    Chronicle.create!(
      event_uuid: event.event_uuid, action: event.event_type, result: "succeeded",
      occurred_at: event.occurred_at, request_id: event.operation_ref,
      metadata: { "surface" => "org", "external_id" => event.external_id, "actor_ref" => actor.public_id },
      changeset: {}, chronicle_retention_policy: policy,
      erasable_at: ChronicleRecordPolicy.erasable_at_for(policy: policy, occurred_at: event.occurred_at),
    )

    assert_nil event.acknowledged_at
    assert_no_difference -> { Chronicle.where(event_uuid: event.event_uuid).count } do
      PasskeyAuditDeliveryJob.perform_now
    end
    assert event.reload.acknowledged_at
  end

  private

  def register_passkey(actor, label)
    PasskeyRegistrationOperation.call!(
      actor: actor,
      passkey_class: ClientPasskey,
      attributes: {
        webauthn_id: "delivery-webauthn-#{label}-#{SecureRandom.uuid}",
        public_key: "delivery-public-key-#{label}",
        description: "Delivery #{label}",
      },
      audit: {
        event_type: "passkey.registered.settings",
        surface: "app",
        actor_ref: actor.public_id,
        operation_ref: SecureRandom.uuid,
        metadata: { reason_code: "settings_registration" },
      },
    )
  end
end
