# frozen_string_literal: true

class ValidateRpBaseOrgStepUpGenerationCheck < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!

  EXPRESSION = "initiating_generation >= 0"

  def up
    validate_check_constraint(:rp_step_up_states, name: "chk_rp_step_up_state_generation")
  end

  def down
    remove_check_constraint(:rp_step_up_states, name: "chk_rp_step_up_state_generation")
    add_check_constraint(
      :rp_step_up_states,
      EXPRESSION,
      name: "chk_rp_step_up_state_generation",
      validate: false,
    )
  end
end
