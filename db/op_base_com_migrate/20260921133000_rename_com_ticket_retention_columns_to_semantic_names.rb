# frozen_string_literal: true

class RenameComTicketRetentionColumnsToSemanticNames < ActiveRecord::Migration[8.2]
  TABLES = %w(
    visitor_verifications visitor_sign_in_flows visitor_sign_out_flows visitor_sign_up_flows
    visitor_step_up_sessions visitor_tokens
  ).freeze
  LONG_INDEX_NAMES = {
    "index_visitor_sign_up_cycles_on_cleanup_status_id_and_purged_at" =>
      "idx_visitor_sign_up_flows_cleanup_status_purge_eligible_at",
    "idx_visitor_sign_up_flows_cleanup_status_purge_eligible_at" =>
      "index_visitor_sign_up_cycles_on_cleanup_status_id_and_purged_at",
  }.freeze

  def up
    rename_columns(:discarded_at, :discard_at)
    rename_columns(:purged_at, :purge_eligible_at)
  end

  def down
    rename_columns(:purge_eligible_at, :purged_at)
    rename_columns(:discard_at, :discarded_at)
  end

  private

  def rename_columns(from, to)
    TABLES.each do |table|
      next unless table_exists?(table)
      next unless column_exists?(table, from)
      next if column_exists?(table, to)

      safety_assured { rename_column(table, from, to) }
      rename_indexes(table, from, to)
    end
  end

  def rename_indexes(table, from, to)
    old_name = from.to_s
    new_name = to.to_s
    connection.indexes(table).each do |index|
      next unless index.name.include?(old_name)

      target_name = LONG_INDEX_NAMES.fetch(index.name) { index.name.sub(old_name, new_name) }
      rename_index(table, index.name, target_name)
    end
  end
end
