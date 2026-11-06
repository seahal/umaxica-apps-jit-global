# frozen_string_literal: true

class AddRpBaseAppStepUpGenerationCheck < ActiveRecord::Migration[8.2]
  def change
    add_check_constraint(
      :rp_step_up_states,
      "initiating_generation >= 0",
      name: "chk_rp_step_up_state_generation",
      validate: false,
    )
  end
end
