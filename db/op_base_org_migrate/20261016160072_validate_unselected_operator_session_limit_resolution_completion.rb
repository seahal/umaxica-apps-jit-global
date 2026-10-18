# typed: false
# frozen_string_literal: true

class ValidateUnselectedOperatorSessionLimitResolutionCompletion < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!

  def change
    validate_check_constraint(
      :operator_session_limit_resolution_transactions,
      name: "chk_operator_resolution_state_timestamps",
    )
  end
end
