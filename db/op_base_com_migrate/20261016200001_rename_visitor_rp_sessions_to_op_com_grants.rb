# typed: false
# frozen_string_literal: true

class RenameVisitorRpSessionsToOpComGrants < ActiveRecord::Migration[8.2]
  OLD_TABLE = :visitor_rp_sessions
  NEW_TABLE = :op_com_grants
  OLD_SEQUENCE = :visitor_rp_sessions_id_seq
  NEW_SEQUENCE = :op_com_grants_id_seq

  INDEX_RENAMES = {
    "index_visitor_rp_sessions_on_visitor_token_id" => "index_op_com_grants_on_visitor_token_id",
    "index_visitor_rp_sessions_on_oidc_client_id" => "index_op_com_grants_on_oidc_client_id",
    "index_visitor_rp_sessions_on_public_id" => "index_op_com_grants_on_public_id",
    "index_visitor_rp_sessions_on_refresh_token_digest" => "index_op_com_grants_on_refresh_token_digest",
    "index_visitor_rp_sessions_on_revoked_at" => "index_op_com_grants_on_revoked_at",
    "idx_active_visitor_rp_session_per_device_session" => "idx_active_op_com_grant_per_device_session",
  }.freeze

  CONSTRAINT_RENAMES = {
    "visitor_rp_sessions_pkey" => "op_com_grants_pkey",
    "chk_visitor_rp_sessions_refresh_delivery_all_or_none" => "chk_op_com_grants_refresh_delivery_all_or_none",
    "fk_visitor_rp_sessions_on_device_session_id" => "fk_op_com_grants_on_device_session_id",
    "visitor_rp_sessions_created_at_not_null" => "op_com_grants_created_at_not_null",
    "visitor_rp_sessions_device_session_id_not_null" => "op_com_grants_device_session_id_not_null",
    "visitor_rp_sessions_id_not_null" => "op_com_grants_id_not_null",
    "visitor_rp_sessions_oidc_client_id_not_null" => "op_com_grants_oidc_client_id_not_null",
    "visitor_rp_sessions_public_id_not_null" => "op_com_grants_public_id_not_null",
    "visitor_rp_sessions_refresh_generation_not_null" => "op_com_grants_refresh_generation_not_null",
    "visitor_rp_sessions_updated_at_not_null" => "op_com_grants_updated_at_not_null",
    "visitor_rp_sessions_visitor_token_id_not_null" => "op_com_grants_visitor_token_id_not_null",
  }.freeze

  def up
    raise "unexpected existing #{NEW_TABLE}" if table_exists?(NEW_TABLE)
    raise "missing #{OLD_TABLE}" unless table_exists?(OLD_TABLE)

    safety_assured do
      rename_table OLD_TABLE, NEW_TABLE
      rename_indexes(NEW_TABLE, INDEX_RENAMES)
      rename_constraints(NEW_TABLE, CONSTRAINT_RENAMES)
      rename_sequence(OLD_SEQUENCE, NEW_SEQUENCE)
    end
  end

  def down
    raise "unexpected existing #{OLD_TABLE}" if table_exists?(OLD_TABLE)
    raise "missing #{NEW_TABLE}" unless table_exists?(NEW_TABLE)

    safety_assured do
      rename_table NEW_TABLE, OLD_TABLE
      rename_indexes(OLD_TABLE, INDEX_RENAMES.invert)
      rename_constraints(OLD_TABLE, CONSTRAINT_RENAMES.invert)
      rename_sequence(NEW_SEQUENCE, OLD_SEQUENCE)
    end
  end

  private

  def rename_indexes(table, mappings)
    mappings.each do |old_name, new_name|
      old_exists = connection.indexes(table).any? { |index| index.name == old_name }
      new_exists = connection.indexes(table).any? { |index| index.name == new_name }
      raise "both #{old_name} and #{new_name} exist on #{table}" if old_exists && new_exists
      raise "neither #{old_name} nor #{new_name} exists on #{table}" unless old_exists || new_exists
      rename_index(table, old_name, new_name) if old_exists
    end
  end

  def rename_constraints(table, mappings)
    mappings.each do |old_name, new_name|
      old_exists = constraint_exists?(table, old_name)
      new_exists = constraint_exists?(table, new_name)
      raise "both #{old_name} and #{new_name} exist on #{table}" if old_exists && new_exists
      raise "neither #{old_name} nor #{new_name} exists on #{table}" unless old_exists || new_exists
      next if new_exists

      execute <<~SQL.squish
        ALTER TABLE #{connection.quote_table_name(table)}
        RENAME CONSTRAINT #{connection.quote_column_name(old_name)}
        TO #{connection.quote_column_name(new_name)}
      SQL
    end
  end

  def constraint_exists?(table, name)
    connection.select_value(<<~SQL.squish).present?
      SELECT 1
        FROM pg_constraint
       WHERE conrelid = #{connection.quote("public.#{table}")}::regclass
         AND conname = #{connection.quote(name.to_s)}
    SQL
  end

  def rename_sequence(old_name, new_name)
    old_exists = sequence_exists?(old_name)
    new_exists = sequence_exists?(new_name)
    raise "both #{old_name} and #{new_name} exist" if old_exists && new_exists
    raise "neither #{old_name} nor #{new_name} exists" unless old_exists || new_exists
    return if new_exists

    execute <<~SQL.squish
      ALTER SEQUENCE #{connection.quote_table_name(old_name)}
      RENAME TO #{connection.quote_table_name(new_name)}
    SQL
  end

  def sequence_exists?(name)
    connection.select_value(<<~SQL.squish).present?
      SELECT to_regclass(#{connection.quote("public.#{name}")})::text
    SQL
  end
end
