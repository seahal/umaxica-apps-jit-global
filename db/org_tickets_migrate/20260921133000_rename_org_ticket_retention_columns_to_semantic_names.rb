# frozen_string_literal: true

class RenameOrgTicketRetentionColumnsToSemanticNames < ActiveRecord::Migration[8.2]
  TABLES = %w(
    operator_sign_in_flows operator_sign_out_flows operator_sign_up_flows
    operator_step_up_sessions operator_tokens operator_verifications
  ).freeze

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

      rename_index(table, index.name, index.name.sub(old_name, new_name))
    end
  end
end
