# typed: false
# frozen_string_literal: true

class ValidateVisitorSessionLimitResolutionWaitingSlot < ActiveRecord::Migration[8.2]
  def up
    validate_check_constraint(
      :visitor_session_limit_resolution_transactions,
      name: "chk_visitor_resolution_waiting_slot_state",
    )
  end

  def down
    raise ActiveRecord::IrreversibleMigration, "waiting-slot lease validation is forward-only"
  end
end
