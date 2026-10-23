# frozen_string_literal: true

class RequireClientSecurityMode < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!

  def up
    validate_foreign_key(:clients, :client_security_modes)
    validate_check_constraint(:clients, name: "chk_clients_security_mode_nn")
    change_column_null(:clients, :security_mode_id, false)
    remove_check_constraint(:clients, name: "chk_clients_security_mode_nn")
    add_index(:clients, :security_mode_id, algorithm: :concurrently)
  end

  def down
    remove_index(:clients, :security_mode_id, algorithm: :concurrently)
    add_check_constraint(:clients, "security_mode_id IS NOT NULL", name: "chk_clients_security_mode_nn", validate: false)
    change_column_null(:clients, :security_mode_id, true)
  end
end
