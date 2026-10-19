# frozen_string_literal: true

class AddWithdrawalDeadlinesToVisitors < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!

  def change
    add_column :visitors, :recovery_available_at, :datetime unless column_exists?(:visitors, :recovery_available_at)
    add_column :visitors, :early_termination_available_at, :datetime unless column_exists?(:visitors, :early_termination_available_at)

    add_index :visitors, :recovery_available_at,
              where: "recovery_available_at IS NOT NULL",
              if_not_exists: true, algorithm: :concurrently
    add_index :visitors, :early_termination_available_at,
              where: "early_termination_available_at IS NOT NULL",
              if_not_exists: true, algorithm: :concurrently
  end
end
