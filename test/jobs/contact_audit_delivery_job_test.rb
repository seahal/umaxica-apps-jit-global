# frozen_string_literal: true

require "test_helper"

class ContactAuditDeliveryJobTest < ActiveSupport::TestCase
  setup do
    ChronicleRetentionPolicy.find_or_create_by!(code: "security") do |policy|
      policy.name = "Security"
      policy.duration_days = 365
      policy.permanent = false
    end
  end

  test "delivery rejects the nearest batching boundaries and type-appropriate sentinels before writing" do
    [nil, "", 0, 501, 1.5].each do |invalid_size|
      assert_no_difference "Chronicle.count" do
        assert_raises(ArgumentError) { ContactAuditDeliveryJob.perform_now(batch_size: invalid_size) }
      end
    end
    [1, 2, 499, 500].each do |valid_size|
      assert_nothing_raised { ContactAuditDeliveryJob.perform_now(batch_size: valid_size) }
    end
  end

  test "a conflicting Contact audit does not starve later pages" do
    poison = ClientContactAuditOutbox.record!(
      contact_kind: "email", event_name: "finalized", owner_ref: "owner-one",
      contact_ref: "contact-one", operation_ref: SecureRandom.uuid, actor_ref: "owner-one",
    )
    later = ClientContactAuditOutbox.record!(
      contact_kind: "email", event_name: "finalized", owner_ref: "owner-two",
      contact_ref: "contact-two", operation_ref: SecureRandom.uuid, actor_ref: "owner-two",
    )
    policy = ChronicleRetentionPolicy.find_by!(code: "security")
    Chronicle.create!(
      event_uuid: poison.event_uuid, action: "contact.email.finalized", result: "succeeded",
      occurred_at: poison.occurred_at, request_id: poison.operation_ref, metadata: { "owner_ref" => "wrong-owner" },
      changeset: {}, chronicle_retention_policy: policy,
      erasable_at: ChronicleRecordPolicy.erasable_at_for(policy: policy, occurred_at: poison.occurred_at),
    )

    assert_raises(ArgumentError) { ContactAuditDeliveryJob.perform_now(batch_size: 1) }
    assert_nil poison.reload.acknowledged_at
    assert_predicate later.reload.acknowledged_at, :present?
    assert_equal 1, Chronicle.where(event_uuid: later.event_uuid).count
  end

  test "a conflicting Chronicle event UUID is never acknowledged in the Source" do
    [ClientContactAuditOutbox].each do |model|
      model.transaction(requires_new: true) do
        event = model.record!(
          contact_kind: "telephone", event_name: "released", owner_ref: "owner",
          contact_ref: "contact", operation_ref: SecureRandom.uuid, actor_ref: nil,
        )
        Chronicle.transaction(requires_new: true) do
          policy = ChronicleRetentionPolicy.find_by!(code: "security")
          Chronicle.create!(
            event_uuid: event.event_uuid, action: "contact.telephone.released", result: "succeeded",
            occurred_at: event.occurred_at, request_id: event.operation_ref, metadata: { "owner_ref" => "wrong-owner" },
            changeset: {}, chronicle_retention_policy: policy,
            erasable_at: ChronicleRecordPolicy.erasable_at_for(policy: policy, occurred_at: event.occurred_at),
          )
          assert_raises(ArgumentError) { ContactAuditDeliveryJob.perform_now }
          assert_nil event.reload.acknowledged_at
          assert_equal 1, Chronicle.where(event_uuid: event.event_uuid).count
          raise ActiveRecord::Rollback
        end
        raise ActiveRecord::Rollback
      end
    end
  end

  test "Source acknowledgment rollback preserves Chronicle and rescan delivers the Source once" do
    [ClientContactAuditOutbox].each do |model|
      event =
        model.transaction do
          model.record!(
            contact_kind: "email", event_name: "finalized", owner_ref: "owner-ref",
            contact_ref: "contact-ref", operation_ref: SecureRandom.uuid, actor_ref: "owner-ref",
          )
        end
      model.transaction(requires_new: true) do
        ContactAuditDeliveryJob.perform_now

        assert event.reload.acknowledged_at
        assert_equal 1, Chronicle.where(event_uuid: event.event_uuid).count
        raise ActiveRecord::Rollback
      end

      assert_nil event.reload.acknowledged_at
      assert_equal 1, Chronicle.where(event_uuid: event.event_uuid).count
      assert_no_difference -> { Chronicle.where(event_uuid: event.event_uuid).count } do
        ContactAuditDeliveryJob.perform_now
      end
      assert event.reload.acknowledged_at
      audit = Chronicle.find_by!(event_uuid: event.event_uuid)

      assert_equal "contact.email.finalized", audit.action
      assert_equal event.operation_ref, audit.request_id
      assert_equal event.occurred_at, audit.occurred_at
      assert_equal event.owner_ref, audit.metadata.fetch("owner_ref")
      assert_equal event.contact_ref, audit.metadata.fetch("contact_ref")
      assert_equal event.actor_ref, audit.metadata.fetch("actor_ref")
      assert_equal "app", audit.metadata.fetch("surface")
    end
  end

  test "Contact mutation and Source intent roll back together" do
    owner = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL)
    contact = ClientEmail.create!(user_id: owner.id, address: "outbox@example.test", confirm_policy: "1")
    operation_ref = SecureRandom.uuid
    ClientEmail.transaction(requires_new: true) do
      contact.finalize_binding!
      ClientContactAuditOutbox.record!(
        contact_kind: "email", event_name: "finalized", owner_ref: owner.public_id,
        contact_ref: contact.public_id, operation_ref: operation_ref,
        actor_ref: owner.public_id,
      )

      assert_predicate contact.reload, :binding_effective?
      assert ClientContactAuditOutbox.exists?(operation_ref: operation_ref)
      raise ActiveRecord::Rollback
    end

    assert_not contact.reload.binding_effective?
    assert_not ClientContactAuditOutbox.exists?(operation_ref: operation_ref)
  end

  test "invalid Contact audit event cannot commit its binding" do
    owner = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL)
    contact = ClientTelephone.create!(user_id: owner.id, number: "+819012345681", confirm_policy: "1")
    assert_raises(ActiveRecord::RecordInvalid) do
      ClientTelephone.transaction(requires_new: true) do
        contact.finalize_binding!
        ClientContactAuditOutbox.record!(
          contact_kind: "telephone", event_name: "unknown", owner_ref: owner.public_id,
          contact_ref: contact.public_id, operation_ref: SecureRandom.uuid, actor_ref: nil,
        )
      end
    end
    assert_not contact.reload.binding_effective?
  end
end
