# typed: false
# frozen_string_literal: true

class AddWaitingSlotToClientSessionLimitResolutionTransactions < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!

  TABLE = :client_session_limit_resolution_transactions
  STATE_CONSTRAINT = "chk_client_resolution_state_timestamps"
  WAITING_SLOT_CONSTRAINT = "chk_client_resolution_waiting_slot_state"
  WAITING_ACTOR_INDEX = "idx_client_resolution_waiting_actor"
  STATE_FACTS = "(state_id = 10 AND selected_at IS NULL AND resolved_at IS NULL AND cancelled_at IS NULL AND expired_at IS NULL) OR (state_id = 20 AND selected_at IS NOT NULL AND resolved_at IS NULL AND cancelled_at IS NULL AND expired_at IS NULL) OR (state_id = 100 AND selected_at IS NOT NULL AND resolved_at IS NOT NULL AND cancelled_at IS NULL AND expired_at IS NULL) OR (state_id = 910 AND expired_at IS NOT NULL AND resolved_at IS NULL AND cancelled_at IS NULL) OR (state_id = 920 AND cancelled_at IS NOT NULL AND resolved_at IS NULL AND expired_at IS NULL)"

  def up
    raise ActiveRecord::MigrationError, "#{TABLE} must exist before adding the waiting slot" unless table_exists?(TABLE)

    add_column(TABLE, :waiting_slot, :integer, limit: 2) unless column_exists?(TABLE, :waiting_slot)
    raise_if_open_rows_require_reconciliation!

    remove_check_constraint(TABLE, name: STATE_CONSTRAINT, if_exists: true)
    add_check_constraint(
      TABLE, STATE_FACTS, name: STATE_CONSTRAINT, if_not_exists: true, validate: false,
    )
    add_check_constraint(
      TABLE,
      "((state_id IN (10, 20) AND waiting_slot IS NOT NULL AND waiting_slot = 1) OR (state_id IN (100, 910, 920) AND waiting_slot IS NULL))",
      name: WAITING_SLOT_CONSTRAINT,
      if_not_exists: true,
      validate: false,
    )
    add_index(
      TABLE, :actor_ref, unique: true, where: "waiting_slot = 1", name: WAITING_ACTOR_INDEX,
      if_not_exists: true, algorithm: :concurrently,
    )
  end

  def down
    raise ActiveRecord::IrreversibleMigration, "waiting-slot lease preparation is forward-only"
  end

  private

  def raise_if_open_rows_require_reconciliation!
    rows = select_all(<<~SQL.squish)
      SELECT id, actor_ref, state_id, started_at
      FROM #{TABLE}
      WHERE state_id IN (10, 20)
      ORDER BY actor_ref, started_at, id
    SQL
    return if rows.empty?

    details = rows.map do |row|
      "id=#{row.fetch("id")} actor_ref=#{row.fetch("actor_ref")} state_id=#{row.fetch("state_id")}"
    end.join(", ")
    raise ActiveRecord::MigrationError,
          "#{TABLE} has existing open resolutions requiring named actor-lock reconciliation before waiting-slot constraints: #{details}"
  end
end
