# frozen_string_literal: true

class CreateClientSocialAuditOutboxes < ActiveRecord::Migration[8.2]
  def change
    create_table(:client_social_audit_outboxes) do |t|
      t.uuid(:event_uuid, null: false)
      t.string(:operation_ref, null: false)
      t.string(:owner_ref, null: false)
      t.string(:identity_ref, null: false)
      t.string(:provider, null: false)
      t.string(:provider_subject_digest, null: false)
      t.string(:event_name, null: false)
      t.datetime(:occurred_at, null: false)
      t.datetime(:released_at)
      t.datetime(:acknowledged_at)
      t.timestamps
    end
    add_index(:client_social_audit_outboxes, :event_uuid, unique: true)
    add_index(
      :client_social_audit_outboxes, :id,
      where: "acknowledged_at IS NULL", name: "client_social_audit_pending",
    )
    add_check_constraint(
      :client_social_audit_outboxes,
      "provider IN ('apple', 'google')", name: "client_social_audit_provider",
    )
    add_check_constraint(
      :client_social_audit_outboxes,
      "event_name IN ('linked', 'unlinked')", name: "client_social_audit_event",
    )
    add_check_constraint(
      :client_social_audit_outboxes,
      "operation_ref <> '' AND owner_ref <> '' AND identity_ref <> ''",
      name: "client_social_audit_references",
    )
    add_check_constraint(
      :client_social_audit_outboxes,
      "acknowledged_at IS NULL OR acknowledged_at >= occurred_at",
      name: "client_social_audit_acknowledgment",
    )
  end
end
