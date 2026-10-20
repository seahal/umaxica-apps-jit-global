# frozen_string_literal: true

class MakeAppZenithRequiredColumnsNotNull < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!

  COLUMNS = [
    [:client_withdrawal_flow_events, :from_status_id, "chk_client_withdrawal_events_from_status_nn"],
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
