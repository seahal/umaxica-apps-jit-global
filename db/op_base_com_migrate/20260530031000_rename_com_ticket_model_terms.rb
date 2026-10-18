# frozen_string_literal: true

class RenameComTicketModelTerms < ActiveRecord::Migration[8.1]
  TABLE_RENAMES = {
    visitor_sign_in_cycles: :visitor_sign_in_flows,
    visitor_sign_in_cycle_statuses: :visitor_sign_in_flow_statuses,
    visitor_sign_up_cycles: :visitor_sign_up_flows,
    visitor_sign_up_cycle_statuses: :visitor_sign_up_flow_statuses,
    visitor_sign_up_cycle_cleanup_statuses: :visitor_sign_up_flow_cleanup_statuses,
    visitor_sign_out_cycles: :visitor_sign_out_flows,
    visitor_sign_out_cycle_statuses: :visitor_sign_out_flow_statuses,
    visitor_sign_out_cycle_kinds: :visitor_sign_out_flow_kinds,
  }.freeze

  def up
    TABLE_RENAMES.each { |old_table, new_table| rename_table_strict old_table, new_table }
  end

  def down
    TABLE_RENAMES.to_a.reverse_each { |old_table, new_table| rename_table_strict new_table, old_table }
  end
end
