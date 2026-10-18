# frozen_string_literal: true

class RenameRetentionColumnsToDiscardedAndPurged < ActiveRecord::Migration[8.2]
  def up
    rename_retention_columns(
      from_discard: :lapses_at,
      to_discard: :discarded_at,
      from_purge: :purge_at,
      to_purge: :purged_at
    )
  end

  def down
    rename_retention_columns(
      from_discard: :discarded_at,
      to_discard: :lapses_at,
      from_purge: :purged_at,
      to_purge: :purge_at
    )
  end

  private

  def rename_retention_columns(from_discard:, to_discard:, from_purge:, to_purge:)
    connection.tables.sort.each do |table|
      rename_column_if_present(table, from_discard, to_discard)
      rename_column_if_present(table, from_purge, to_purge)
      rename_index_if_present(table, from_discard, to_discard)
      rename_index_if_present(table, from_purge, to_purge)
    end
  end

  def rename_column_if_present(table, from, to)
    return unless column_exists?(table, from)
    return if column_exists?(table, to)

    rename_column(table, from, to)
  end

  def rename_index_if_present(table, from, to)
    old_name = "index_#{table}_on_#{from}"
    new_name = "index_#{table}_on_#{to}"
    names = connection.indexes(table).map(&:name)
    return unless names.include?(old_name)
    return if names.include?(new_name)

    rename_index(table, old_name, new_name)
  end
end
