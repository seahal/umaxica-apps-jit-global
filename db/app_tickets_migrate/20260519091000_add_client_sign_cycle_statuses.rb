# frozen_string_literal: true
class AddClientSignCycleStatuses < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!

  def change
    create_status_table(:client_sign_in_cycle_statuses)
    create_status_table(:client_sign_up_cycle_statuses)

    add_cycle_status(:app_sign_in_cycles, :client_sign_in_cycle_statuses)
    add_cycle_status(:app_sign_up_cycles, :client_sign_up_cycle_statuses)
  end

  private

  def create_status_table(table_name)
    return if table_exists?(table_name)

    create_table table_name do |_t|
    end
  end

  def add_cycle_status(cycle_table, status_table)
    add_column cycle_table, :status_id, :bigint, default: 10, null: false unless column_exists?(cycle_table, :status_id)
    add_index cycle_table, :status_id, name: "index_#{cycle_table}_on_status_id", if_not_exists: true, algorithm: :concurrently

    return if foreign_key_exists?(cycle_table, status_table, column: :status_id)

    add_foreign_key cycle_table, status_table, column: :status_id, validate: false
  end
end
