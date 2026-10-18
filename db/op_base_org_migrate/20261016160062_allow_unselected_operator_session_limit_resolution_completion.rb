# typed: false
# frozen_string_literal: true

class AllowUnselectedOperatorSessionLimitResolutionCompletion < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!

  TABLE = :operator_session_limit_resolution_transactions
  CONSTRAINT = "chk_operator_resolution_state_timestamps"
  STATE_FACTS = "(state_id = 10 AND selected_at IS NULL AND resolved_at IS NULL AND cancelled_at IS NULL AND expired_at IS NULL) OR (state_id = 20 AND selected_at IS NOT NULL AND resolved_at IS NULL AND cancelled_at IS NULL AND expired_at IS NULL) OR (state_id = 100 AND resolved_at IS NOT NULL AND cancelled_at IS NULL AND expired_at IS NULL) OR (state_id = 910 AND expired_at IS NOT NULL AND resolved_at IS NULL AND cancelled_at IS NULL) OR (state_id = 920 AND cancelled_at IS NOT NULL AND resolved_at IS NULL AND expired_at IS NULL)"

  def up
    remove_check_constraint(TABLE, name: CONSTRAINT, if_exists: true)
    add_check_constraint(TABLE, STATE_FACTS, name: CONSTRAINT, if_not_exists: true, validate: false)
  end

  def down
    raise ActiveRecord::IrreversibleMigration, "session-limit resolution state facts are forward-only"
  end
end
