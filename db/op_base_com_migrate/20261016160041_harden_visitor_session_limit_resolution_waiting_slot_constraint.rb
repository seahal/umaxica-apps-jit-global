# typed: false
# frozen_string_literal: true

class HardenVisitorSessionLimitResolutionWaitingSlotConstraint < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!

  TABLE = :visitor_session_limit_resolution_transactions
  CONSTRAINT = "chk_visitor_resolution_waiting_slot_state"
  WAITING_SLOT_FACTS = "((state_id IN (10, 20) AND waiting_slot IS NOT NULL AND waiting_slot = 1) OR (state_id IN (100, 910, 920) AND waiting_slot IS NULL))"

  def up
    remove_check_constraint(TABLE, name: CONSTRAINT, if_exists: true)
    add_check_constraint(TABLE, WAITING_SLOT_FACTS, name: CONSTRAINT, if_not_exists: true, validate: false)
  end

  def down
    raise ActiveRecord::IrreversibleMigration, "waiting-slot state constraints are forward-only"
  end
end
