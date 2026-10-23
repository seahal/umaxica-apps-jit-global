# frozen_string_literal: true

class RequireOperatorSecurityMode < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!

  def up
    validate_foreign_key(:operators, :operator_security_modes)
    validate_check_constraint(:operators, name: "chk_operators_security_mode_nn")
    change_column_null(:operators, :security_mode_id, false)
    remove_check_constraint(:operators, name: "chk_operators_security_mode_nn")
    add_index(:operators, :security_mode_id, algorithm: :concurrently)
  end

  def down
    remove_index(:operators, :security_mode_id, algorithm: :concurrently)
    add_check_constraint(:operators, "security_mode_id IS NOT NULL", name: "chk_operators_security_mode_nn", validate: false)
    change_column_null(:operators, :security_mode_id, true)
  end
end
