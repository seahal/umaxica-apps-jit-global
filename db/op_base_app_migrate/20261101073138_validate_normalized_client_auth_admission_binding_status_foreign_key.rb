# frozen_string_literal: true

class ValidateNormalizedClientAuthAdmissionBindingStatusForeignKey < ActiveRecord::Migration[8.2]
  TABLE = :client_auth_admission_bindings
  REFERENCE_TABLE = :client_auth_admission_binding_statuses
  FOREIGN_KEY_NAME = "fk_client_admission_bindings_status"

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
