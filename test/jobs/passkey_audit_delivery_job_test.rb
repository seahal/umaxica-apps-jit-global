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

  test "continues to the next batch after one event fails and leaves it retryable" do
    batch_size = ClientPasskeyAuditOutbox.where(acknowledged_at: nil).count + 1

    assert_operator batch_size, :<=, 500
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

    error = assert_raises(ArgumentError) { PasskeyAuditDeliveryJob.perform_now(batch_size: batch_size) }
    assert_equal "Passkey Chronicle event identity conflicts with its source", error.message
    assert_nil first_event.reload.acknowledged_at
    assert second_event.reload.acknowledged_at
    assert Chronicle.exists?(event_uuid: second_event.event_uuid)
  end

  test "an unavailable APP source does not prevent ORG audit delivery" do
    client = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL)
    client_key = register_passkey(client, "source-unavailable")
    client_event = ClientPasskeyAuditOutbox.find_by!(external_id: client_key.external_id)
    operator = Operator.create!(security_mode_id: SecurityModeConfigurable::ADVANCED)
    passkey = PasskeyRegistrationOperation.call!(
      actor: operator, passkey_class: OperatorPasskey,
      attributes: { webauthn_id: SecureRandom.uuid, public_key: "org-audit-source-isolation" },
      audit: { event_type: "passkey.registered.settings", surface: "org", actor_ref: operator.public_id },
    )
    event = OperatorPasskeyAuditOutbox.find_by!(external_id: passkey.external_id)
    unavailable = ->(*) { raise ActiveRecord::ConnectionNotEstablished, "injected APP source outage" }

    ClientPasskeyAuditOutbox.stub(:where, unavailable) do
      assert_raises(ActiveRecord::ConnectionNotEstablished) { PasskeyAuditDeliveryJob.perform_now(batch_size: 1) }
    end

    assert_nil client_event.reload.acknowledged_at
    assert_not Chronicle.exists?(event_uuid: client_event.event_uuid)
    assert_predicate event.reload.acknowledged_at, :present?
    assert_equal 1, Chronicle.where(event_uuid: event.event_uuid).count
    PasskeyAuditDeliveryJob.perform_now(batch_size: 1)

    assert_predicate client_event.reload.acknowledged_at, :present?
    assert_equal 1, Chronicle.where(event_uuid: client_event.event_uuid).count
    assert_equal 1, Chronicle.where(event_uuid: event.event_uuid).count
  end

  test "refuses forged authoritative metadata and continues delivery on each surface" do
    [
      [Client, ClientPasskey, ClientPasskeyAuditOutbox, "app", SecurityModeConfigurable::NORMAL],
      [Operator, OperatorPasskey, OperatorPasskeyAuditOutbox, "org", SecurityModeConfigurable::ADVANCED],
    ].each do |actor_class, passkey_class, outbox_class, surface, security_mode|
      actor = actor_class.create!(security_mode_id: security_mode)
      %w(surface external_id actor_ref).each do |reserved_key|
        first = PasskeyRegistrationOperation.call!(
          actor: actor, passkey_class: passkey_class,
          attributes: { webauthn_id: SecureRandom.uuid, public_key: "forged-metadata-key" },
          audit: { event_type: "passkey.registered.settings", surface: surface },
        )
        second = PasskeyRegistrationOperation.call!(
          actor: actor, passkey_class: passkey_class,
          attributes: { webauthn_id: SecureRandom.uuid, public_key: "valid-metadata-key" },
          audit: { event_type: "passkey.registered.settings", surface: surface },
        )
        invalid = outbox_class.find_by!(external_id: first.external_id)
        valid = outbox_class.find_by!(external_id: second.external_id)
        outbox_class.where(id: invalid.id).update_all(metadata: { reserved_key => "forged-reference" })

        assert_raises(ArgumentError) { PasskeyAuditDeliveryJob.perform_now(batch_size: 1) }
        assert_nil invalid.reload.acknowledged_at
        assert_not Chronicle.exists?(event_uuid: invalid.event_uuid)
        assert valid.reload.acknowledged_at
        assert Chronicle.exists?(event_uuid: valid.event_uuid)

        outbox_class.where(id: invalid.id).update_all(metadata: {})
        PasskeyAuditDeliveryJob.perform_now(batch_size: 1)

        assert invalid.reload.acknowledged_at
      end
    end
  end

  test "delivery after credential deletion preserves system actor and original occurrence time" do
    actor = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL)
    passkey = PasskeyRegistrationOperation.call!(
      actor: actor, passkey_class: ClientPasskey,
      attributes: { webauthn_id: SecureRandom.uuid, public_key: "system-purge-key" },
      audit: { event_type: "passkey.registered.settings", surface: "app" },
    )
    external_id = passkey.external_id
    occurred_at = ClientPasskey.database_now - 1.hour
    event = nil
    ClientPasskey.transaction do
      event = PasskeyAuditOutbox.record_for!(
        passkey: passkey, event_type: "passkey.purged", surface: "app",
        actor_ref: nil, occurred_at: occurred_at,
      )
      passkey.destroy!
    end

    PasskeyAuditDeliveryJob.perform_now

    audit = Chronicle.find_by!(event_uuid: event.event_uuid)

    assert_not ClientPasskey.exists?(external_id: external_id)
    assert_equal external_id, audit.metadata.fetch("external_id")
    assert_equal "app", audit.metadata.fetch("surface")
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

  test "refuses a matching UUID with conflicting Chronicle actor or subject" do
    actor = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL)
    passkey = register_passkey(actor, "conflicting-actor")
    event = ClientPasskeyAuditOutbox.find_by!(external_id: passkey.external_id)
    policy = ChronicleRecordPolicy.retention_policy_for(action: event.event_type)
    audit = Chronicle.create!(
      event_uuid: event.event_uuid, action: event.event_type, result: "succeeded",
      occurred_at: event.occurred_at, request_id: event.operation_ref,
      metadata: { "surface" => "app",
                  "external_id" => event.external_id.to_s,
                  "actor_ref" => actor.public_id,
                  "reason_code" => "settings_registration", },
      actor_type: "Client", actor_id: actor.id, changeset: {}, chronicle_retention_policy: policy,
      erasable_at: ChronicleRecordPolicy.erasable_at_for(policy: policy, occurred_at: event.occurred_at),
    )

    assert_raises(ArgumentError) { PasskeyAuditDeliveryJob.perform_now }
    assert_nil event.reload.acknowledged_at
    audit.update!(actor_type: nil, actor_id: nil, subject_type: "Client", subject_id: actor.id)
    assert_raises(ArgumentError) { PasskeyAuditDeliveryJob.perform_now }
    assert_nil event.reload.acknowledged_at
  end

  test "ORG conflicting Chronicle actor stays pending while a later event is delivered" do
    actor = Operator.create!(security_mode_id: SecurityModeConfigurable::ADVANCED)
    passkeys =
      2.times.map do
        PasskeyRegistrationOperation.call!(
          actor: actor, passkey_class: OperatorPasskey,
          attributes: { webauthn_id: SecureRandom.uuid, public_key: "org-audit-conflict-key" },
          audit: { event_type: "passkey.registered.settings", surface: "org", actor_ref: actor.public_id },
        )
      end
    first, second = passkeys.map { |passkey| OperatorPasskeyAuditOutbox.find_by!(external_id: passkey.external_id) }
    policy = ChronicleRecordPolicy.retention_policy_for(action: first.event_type)
    Chronicle.create!(
      event_uuid: first.event_uuid, action: first.event_type, result: "succeeded",
      occurred_at: first.occurred_at, request_id: first.operation_ref,
      metadata: { "surface" => "org", "external_id" => first.external_id, "actor_ref" => actor.public_id },
      actor_type: "Operator", actor_id: actor.id, changeset: {}, chronicle_retention_policy: policy,
      erasable_at: ChronicleRecordPolicy.erasable_at_for(policy: policy, occurred_at: first.occurred_at),
    )

    assert_raises(ArgumentError) { PasskeyAuditDeliveryJob.perform_now(batch_size: 1) }
    assert_nil first.reload.acknowledged_at
    assert_predicate second.reload.acknowledged_at, :present?
    assert Chronicle.exists?(event_uuid: second.event_uuid)
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
