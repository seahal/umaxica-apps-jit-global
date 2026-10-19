# frozen_string_literal: true

class AddWithdrawalDeadlinesToClients < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!

  def change
    add_column :clients, :recovery_available_at, :datetime unless column_exists?(:clients, :recovery_available_at)
    add_column :clients, :early_termination_available_at, :datetime unless column_exists?(:clients, :early_termination_available_at)

    add_index :clients, :recovery_available_at,
              where: "recovery_available_at IS NOT NULL",
              if_not_exists: true, algorithm: :concurrently
    add_index :clients, :early_termination_available_at,
              where: "early_termination_available_at IS NOT NULL",
              if_not_exists: true, algorithm: :concurrently
  end
end
