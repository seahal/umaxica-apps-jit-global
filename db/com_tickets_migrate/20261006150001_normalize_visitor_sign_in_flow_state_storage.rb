# frozen_string_literal: true

require_relative "../migration_support/sign_in_flow_state_storage"

class NormalizeVisitorSignInFlowStateStorage < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!
  include SignInFlowStateStorage

  def up
    normalize_sign_in_flow_state_storage(
      flow_table: :visitor_sign_in_flows,
      status_table: :visitor_sign_in_flow_statuses,
      state_table: :visitor_sign_in_flow_states,
      state_index: "index_visitor_sign_in_flows_on_state",
      status_index: "index_visitor_sign_in_flows_on_status_id",
      state_constraint: "chk_visitor_sign_in_cycles_status_state",
      step_constraint: "chk_visitor_sign_in_cycles_status_step",
      completed_constraint: "chk_visitor_sign_in_flows_state_completed_at",
    )
  end

  def down
    raise ActiveRecord::IrreversibleMigration, "sign-in flow state storage normalization is irreversible"
  end
end
