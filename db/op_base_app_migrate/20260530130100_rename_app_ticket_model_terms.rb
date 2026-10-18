# frozen_string_literal: true

class RenameAppTicketModelTerms < ActiveRecord::Migration[8.1]
  TABLE_RENAMES = {
    client_social_callback_states: :client_oauth_callback_states,
    client_sign_in_cycles: :client_sign_in_flows,
    client_sign_in_cycle_statuses: :client_sign_in_flow_statuses,
    client_sign_up_cycles: :client_sign_up_flows,
    client_sign_up_cycle_statuses: :client_sign_up_flow_statuses,
    client_sign_up_cycle_cleanup_statuses: :client_sign_up_flow_cleanup_statuses,
    client_sign_out_cycles: :client_sign_out_flows,
    client_sign_out_cycle_statuses: :client_sign_out_flow_statuses,
    client_sign_out_cycle_kinds: :client_sign_out_flow_kinds,
  }.freeze

  def up
    TABLE_RENAMES.each { |old_table, new_table| rename_table_strict old_table, new_table }
  end

  def down
    TABLE_RENAMES.to_a.reverse_each { |old_table, new_table| rename_table_strict new_table, old_table }
  end
end
