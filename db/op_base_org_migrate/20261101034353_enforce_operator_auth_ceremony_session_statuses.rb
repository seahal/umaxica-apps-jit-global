# frozen_string_literal: true

class EnforceOperatorAuthCeremonySessionStatuses < ActiveRecord::Migration[8.2]
  TABLE = :operator_auth_ceremony_sessions
  STATUS_FACTS = <<~SQL.squish.freeze
    (status_id = 10 AND admitted_at IS NULL AND authentication_method IS NULL AND
      authentication_event_at IS NULL AND revoked_at IS NULL AND completed_at IS NULL AND cancelled_at IS NULL) OR
    (status_id = 20 AND admitted_at IS NOT NULL AND authentication_method IS NULL AND
      authentication_event_at IS NULL AND revoked_at IS NULL AND completed_at IS NULL AND cancelled_at IS NULL) OR
    (status_id = 30 AND admitted_at IS NOT NULL AND authentication_method IS NOT NULL AND
      authentication_event_at IS NOT NULL AND revoked_at IS NULL AND completed_at IS NULL AND cancelled_at IS NULL) OR
    (status_id IN (40, 90) AND revoked_at IS NOT NULL AND completed_at IS NULL AND cancelled_at IS NULL) OR
    (status_id = 91 AND admitted_at IS NOT NULL AND revoked_at IS NULL AND completed_at IS NOT NULL AND cancelled_at IS NULL) OR
    (status_id = 92 AND admitted_at IS NOT NULL AND authentication_method IS NULL AND
      authentication_event_at IS NULL AND revoked_at IS NULL AND completed_at IS NULL AND cancelled_at IS NOT NULL) OR
    (status_id = 93 AND admitted_at IS NOT NULL AND authentication_method IS NOT NULL AND
      authentication_event_at IS NOT NULL AND revoked_at IS NULL AND completed_at IS NULL AND cancelled_at IS NOT NULL)
  SQL

  def up
    add_foreign_key(
      TABLE, :operator_auth_ceremony_session_statuses,
      column: :status_id, name: "fk_operator_auth_ceremony_sessions_status", on_delete: :restrict,
      validate: false,
    )
    add_check_constraint(
      TABLE, "status_id IS NOT NULL",
      name: "operator_auth_ceremony_session_status_present", validate: false,
    )
    add_check_constraint(TABLE, STATUS_FACTS, name: "operator_auth_ceremony_session_status_facts", validate: false)
  end

  def down
    remove_check_constraint(TABLE, name: "operator_auth_ceremony_session_status_facts")
    remove_check_constraint(TABLE, name: "operator_auth_ceremony_session_status_present")
    remove_foreign_key(TABLE, name: "fk_operator_auth_ceremony_sessions_status")
  end
end
