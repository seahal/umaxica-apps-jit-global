# frozen_string_literal: true

class ValidateNormalizedOperatorAuthAdmissionBindingStatusForeignKey < ActiveRecord::Migration[8.2]
  TABLE = :operator_auth_admission_bindings
  REFERENCE_TABLE = :operator_auth_admission_binding_statuses
  FOREIGN_KEY_NAME = "fk_operator_admission_bindings_status"

  def up
    validate_foreign_key(TABLE, REFERENCE_TABLE, name: FOREIGN_KEY_NAME)
  end

  def down
    remove_foreign_key(TABLE, name: FOREIGN_KEY_NAME)
    add_foreign_key(
      TABLE,
      REFERENCE_TABLE,
      column: :status_id,
      name: FOREIGN_KEY_NAME,
      on_delete: :restrict,
      validate: false,
    )
  end
end
