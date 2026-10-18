# frozen_string_literal: true

class AddEntryMethodNotNullToVisitorSignUpFlows < ActiveRecord::Migration[8.2]
  def change
    add_check_constraint :visitor_sign_up_flows, "entry_method IS NOT NULL",
                         name: "visitor_sign_up_flows_entry_method_null", validate: false
  end
end
