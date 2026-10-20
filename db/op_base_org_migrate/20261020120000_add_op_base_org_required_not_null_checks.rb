# frozen_string_literal: true

class AddOpBaseOrgRequiredNotNullChecks < ActiveRecord::Migration[8.2]
  # [table, column, temporary constraint]; the model already requires each column on every save.
  COLUMNS = [
    [:operator_step_up_ceremony_transactions, :audience, "chk_operator_step_up_ceremony_txns_audience_nn"],
    [:operator_step_up_ceremony_transactions, :token_binding, "chk_operator_step_up_ceremony_txns_binding_nn"],
  ].freeze

  def change
    COLUMNS.each do |table, column, name|
      add_check_constraint(table, "#{column} IS NOT NULL", name:, validate: false)
    end
  end
end
