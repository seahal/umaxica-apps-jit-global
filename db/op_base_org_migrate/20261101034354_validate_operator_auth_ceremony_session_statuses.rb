# frozen_string_literal: true

class ValidateOperatorAuthCeremonySessionStatuses < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!

  TABLE = :operator_auth_ceremony_sessions

  def up
    validate_foreign_key(TABLE, name: "fk_operator_auth_ceremony_sessions_status")
    validate_check_constraint(TABLE, name: "operator_auth_ceremony_session_status_present")
    validate_check_constraint(TABLE, name: "operator_auth_ceremony_session_status_facts")
    change_column_null(TABLE, :status_id, false)
    remove_check_constraint(TABLE, name: "operator_auth_ceremony_session_status_present")
  end

  def down
    change_column_null(TABLE, :status_id, true)
  end
end
