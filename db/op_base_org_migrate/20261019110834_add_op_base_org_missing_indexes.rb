# frozen_string_literal: true

class AddOpBaseOrgMissingIndexes < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!

  def change
    add_index(
      :operator_session_limit_resolution_transactions, :state_id,
      name: "idx_operator_session_limit_resolution_txns_on_state_id", algorithm: :concurrently,
    )
    add_index(:op_outbox_events, :logout_flow_participant_id, algorithm: :concurrently)
  end
end
