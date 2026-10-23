# frozen_string_literal: true

class ValidateSignFlowHaltedKeys < ActiveRecord::Migration[8.2]
  def change
    validate_check_constraint(:operator_chronicles, name: "chk_operator_chronicles_sign_flow_halted_keys")
  end
end
