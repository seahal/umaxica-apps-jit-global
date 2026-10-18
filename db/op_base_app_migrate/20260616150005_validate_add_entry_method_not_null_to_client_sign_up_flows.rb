# frozen_string_literal: true

class ValidateAddEntryMethodNotNullToClientSignUpFlows < ActiveRecord::Migration[8.2]
  def up
    validate_check_constraint :client_sign_up_flows, name: "client_sign_up_flows_entry_method_null"
    change_column_null :client_sign_up_flows, :entry_method, false
    remove_check_constraint :client_sign_up_flows, name: "client_sign_up_flows_entry_method_null"
  end

  def down
    add_check_constraint :client_sign_up_flows, "entry_method IS NOT NULL",
                         name: "client_sign_up_flows_entry_method_null", validate: false
    change_column_null :client_sign_up_flows, :entry_method, true
  end
end
