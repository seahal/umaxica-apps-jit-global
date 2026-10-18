# frozen_string_literal: true

class RepairUserTokenReferenceData < ActiveRecord::Migration[8.2]
  REFERENCE_DATA = {
    user_token_binding_methods: [0, 1, 2],
    user_token_dbsc_statuses: [0, 1, 2, 3, 4],
    user_token_kinds: [11, 12, 13],
    user_token_statuses: [0, 1, 2],
  }.freeze

  def up
    safety_assured do
      REFERENCE_DATA.each do |table_name, ids|
        seed_reference_ids(table_name, ids)
      end
    end

    change_column_default(:user_tokens, :user_token_kind_id, from: 0, to: 11)
  end

  def down
    change_column_default(:user_tokens, :user_token_kind_id, from: 11, to: 0)
  end

  private

  def seed_reference_ids(table_name, ids)
    return unless table_exists?(table_name)

    ids.each do |id|
      execute(<<~SQL.squish)
        INSERT INTO #{table_name} (id)
        VALUES (#{connection.quote(id)})
        ON CONFLICT (id) DO NOTHING
      SQL
    end

    ensure_sequence!(table_name, ids.max)
  end

  def ensure_sequence!(table_name, max_id)
    sequence_name = select_value("SELECT pg_get_serial_sequence(#{connection.quote(table_name.to_s)}, 'id')")
    return if sequence_name.blank?

    execute("SELECT setval(#{connection.quote(sequence_name)}, #{Integer(max_id)}, true)")
  end
end
