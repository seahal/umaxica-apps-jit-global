# frozen_string_literal: true

class MakeOpBaseAppRequiredColumnsNotNull < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!

  COLUMNS = [
    [:client_step_up_ceremony_transactions, :audience, "chk_client_step_up_ceremony_txns_audience_nn"],
    [:client_step_up_ceremony_transactions, :token_binding, "chk_client_step_up_ceremony_txns_binding_nn"],
  ].freeze

  # Validating the check first lets SET NOT NULL skip its full-table scan.
  def up
    COLUMNS.each do |table, column, name|
      validate_check_constraint(table, name:)
      change_column_null(table, column, false)
      remove_check_constraint(table, name:)
    end
  end

  def down
    COLUMNS.each do |table, column, name|
      add_check_constraint(table, "#{column} IS NOT NULL", name:, validate: false)
      change_column_null(table, column, true)
    end
  end
end
