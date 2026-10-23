# frozen_string_literal: true

class RequireVisitorSecurityMode < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!

  def up
    validate_foreign_key(:visitors, :visitor_security_modes)
    validate_check_constraint(:visitors, name: "chk_visitors_security_mode_nn")
    change_column_null(:visitors, :security_mode_id, false)
    remove_check_constraint(:visitors, name: "chk_visitors_security_mode_nn")
    add_index(:visitors, :security_mode_id, algorithm: :concurrently)
  end

  def down
    remove_index(:visitors, :security_mode_id, algorithm: :concurrently)
    add_check_constraint(:visitors, "security_mode_id IS NOT NULL", name: "chk_visitors_security_mode_nn", validate: false)
    change_column_null(:visitors, :security_mode_id, true)
  end
end
