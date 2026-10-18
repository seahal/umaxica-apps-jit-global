# frozen_string_literal: true

class RenameOrgTicketModelTerms < ActiveRecord::Migration[8.1]
  TABLE_RENAMES = {
    operator_social_callback_states: :operator_oauth_callback_states,
    operator_sign_in_cycles: :operator_sign_in_flows,
    operator_sign_in_cycle_statuses: :operator_sign_in_flow_statuses,
    operator_sign_up_cycles: :operator_sign_up_flows,
    operator_sign_up_cycle_statuses: :operator_sign_up_flow_statuses,
    operator_sign_out_cycles: :operator_sign_out_flows,
    operator_sign_out_cycle_statuses: :operator_sign_out_flow_statuses,
    operator_sign_out_cycle_kinds: :operator_sign_out_flow_kinds,
  }.freeze

  def up
    TABLE_RENAMES.each { |old_table, new_table| rename_table_strict old_table, new_table }
  end

  def down
    TABLE_RENAMES.to_a.reverse_each { |old_table, new_table| rename_table_strict new_table, old_table }
  end
end
