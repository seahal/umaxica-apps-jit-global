# frozen_string_literal: true

class ConvertStaffIdentityAuditEventsToBigint < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!

  def change
    add_column(:staff_identity_audit_events, :legacy_id, :string)
    add_column(:staff_identity_audit_events, :id_bigint, :bigint)
    add_column(:staff_identity_audits, :event_id_bigint, :bigint)

    add_index(
      :staff_identity_audit_events,
      :legacy_id,
      unique: true,
      algorithm: :concurrently,
      name: "index_staff_identity_audit_events_on_legacy_id",
    )
    add_index(
      :staff_identity_audit_events,
      :id_bigint,
      unique: true,
      algorithm: :concurrently,
      name: "index_staff_identity_audit_events_on_id_bigint",
    )
    add_index(
      :staff_identity_audits,
      :event_id_bigint,
      algorithm: :concurrently,
      name: "index_staff_identity_audits_on_event_id_bigint",
    )
  end
end
