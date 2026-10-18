# frozen_string_literal: true

class ValidateStaffIdentityAuditEventBigintForeignKey < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!

  FOREIGN_KEY = "fk_staff_identity_audits_event_id_bigint"
  EVENT_LEGACY_ID_NOT_NULL = "staff_identity_audit_events_legacy_id_not_null"
  EVENT_BIGINT_ID_NOT_NULL = "staff_identity_audit_events_id_bigint_not_null"
  AUDIT_BIGINT_EVENT_ID_NOT_NULL = "staff_identity_audits_event_id_bigint_not_null"

  def up
    validate_check_constraint(:staff_identity_audit_events, name: EVENT_LEGACY_ID_NOT_NULL)
    validate_check_constraint(:staff_identity_audit_events, name: EVENT_BIGINT_ID_NOT_NULL)
    validate_check_constraint(:staff_identity_audits, name: AUDIT_BIGINT_EVENT_ID_NOT_NULL)
    change_column_null(:staff_identity_audit_events, :legacy_id, false)
    change_column_null(:staff_identity_audits, :event_id, false)
    validate_foreign_key(:staff_identity_audits, name: FOREIGN_KEY)
    remove_check_constraint(:staff_identity_audit_events, name: EVENT_LEGACY_ID_NOT_NULL)
    remove_check_constraint(:staff_identity_audit_events, name: EVENT_BIGINT_ID_NOT_NULL)
    remove_check_constraint(:staff_identity_audits, name: AUDIT_BIGINT_EVENT_ID_NOT_NULL)
  end

  def down
    remove_foreign_key(:staff_identity_audits, name: FOREIGN_KEY)
    add_foreign_key(
      :staff_identity_audits,
      :staff_identity_audit_events,
      column: :event_id,
      primary_key: :id,
      validate: false,
      name: FOREIGN_KEY,
    )
    add_check_constraint(
      :staff_identity_audit_events,
      "legacy_id IS NOT NULL",
      name: EVENT_LEGACY_ID_NOT_NULL,
      validate: false,
    )
    add_check_constraint(
      :staff_identity_audit_events,
      "id IS NOT NULL",
      name: EVENT_BIGINT_ID_NOT_NULL,
      validate: false,
    )
    add_check_constraint(
      :staff_identity_audits,
      "event_id IS NOT NULL",
      name: AUDIT_BIGINT_EVENT_ID_NOT_NULL,
      validate: false,
    )
    change_column_null(:staff_identity_audit_events, :legacy_id, true)
    change_column_null(:staff_identity_audits, :event_id, true)
  end
end
