# frozen_string_literal: true

class AddComZenithRequiredNotNullChecks < ActiveRecord::Migration[8.2]
  # [table, column, temporary constraint]; the model already requires each column on every save.
  COLUMNS = [
    [:visitor_withdrawal_flow_events, :from_status_id, "chk_visitor_withdrawal_events_from_status_nn"],
  ].freeze

  def change
    COLUMNS.each do |table, column, name|
      add_check_constraint(table, "#{column} IS NOT NULL", name:, validate: false)
    end
  end
end
