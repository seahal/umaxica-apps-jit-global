# frozen_string_literal: true

class CreateClientContactAuditOutboxes < ActiveRecord::Migration[8.2]
  public

  def change
    create_table(:client_contact_audit_outboxes) do |t|
      t.uuid(:event_uuid, null: false)
      t.string(:contact_kind, null: false)
      t.string(:event_name, null: false)
      t.string(:owner_ref, null: false)
      t.string(:contact_ref, null: false)
      t.string(:operation_ref, null: false)
      t.string(:actor_ref)
      t.datetime(:occurred_at, null: false)
      t.datetime(:acknowledged_at)
      t.timestamps
    end
    add_index(:client_contact_audit_outboxes, :event_uuid, unique: true)
    add_index(
      :client_contact_audit_outboxes, :id,
      where: "acknowledged_at IS NULL", name: "client_contact_audit_pending",
    )
    add_check_constraint(
      :client_contact_audit_outboxes, "contact_kind IN ('email', 'telephone')",
      name: "client_contact_audit_kind",
    )
    add_check_constraint(
      :client_contact_audit_outboxes, "event_name IN ('finalized', 'released')",
      name: "client_contact_audit_event",
    )
    add_check_constraint(
      :client_contact_audit_outboxes,
      "owner_ref <> '' AND contact_ref <> '' AND operation_ref <> ''",
      name: "client_contact_audit_references",
    )
    add_check_constraint(
      :client_contact_audit_outboxes,
      "acknowledged_at IS NULL OR acknowledged_at >= occurred_at",
      name: "client_contact_audit_acknowledgment",
    )
  end
end
