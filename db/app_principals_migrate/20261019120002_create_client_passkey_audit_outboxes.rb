# frozen_string_literal: true

class CreateClientPasskeyAuditOutboxes < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!

  def change
    create_table :client_passkey_audit_outboxes do |t|
      t.uuid :event_uuid, null: false
      t.string :event_type, null: false
      t.string :surface, null: false
      t.uuid :external_id, null: false
      t.string :actor_ref
      t.string :operation_ref
      t.jsonb :metadata, null: false, default: {}
      t.datetime :occurred_at, null: false
      t.datetime :acknowledged_at
      t.timestamps
    end
    add_index :client_passkey_audit_outboxes, :event_uuid, unique: true, algorithm: :concurrently
    add_index :client_passkey_audit_outboxes, :id, where: "acknowledged_at IS NULL", name: "client_passkey_audit_pending", algorithm: :concurrently
    add_check_constraint :client_passkey_audit_outboxes,
                         "event_type IN ('passkey.registered.signup', 'passkey.registered.settings', 'passkey.description_changed', 'passkey.removed', 'passkey.revoked', 'passkey.registration_cancelled', 'passkey.purged')",
                         name: "client_passkey_audit_event"
    add_check_constraint :client_passkey_audit_outboxes, "surface = 'app'", name: "client_passkey_audit_surface"
    add_check_constraint :client_passkey_audit_outboxes,
                         "acknowledged_at IS NULL OR acknowledged_at >= occurred_at",
                         name: "client_passkey_audit_acknowledgment"
  end
end
