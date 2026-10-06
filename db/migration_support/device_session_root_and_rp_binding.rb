# frozen_string_literal: true

# Performs the one-time conversion from rotating root-token ownership to the
# stable device-session parent used by Browser RP sessions. Every relationship
# is either already present or derived from a single token row; ambiguous rows
# stop the migration before a constraint or index is changed.
module DeviceSessionRootAndRpBinding
  module_function

  def up(
    migration,
    token_table:,
    device_table:,
    rp_table:,
    actor_column:,
    token_parent_column:,
    old_active_index:,
    new_active_index:,
    rp_device_foreign_key:
  )
    connection = migration.connection

    migration.safety_assured do
      connection.transaction do
        connection.execute("SET LOCAL lock_timeout = '5s'")
        connection.execute("SET LOCAL statement_timeout = '30min'")

        verify_existing_token_bindings!(
          connection,
          token_table:,
          device_table:,
          actor_column:,
        )
        backfill_missing_token_bindings!(
          connection,
          token_table:,
          device_table:,
          actor_column:,
        )
        verify_current_token_pointers!(
          connection,
          token_table:,
          device_table:,
          actor_column:,
        )
        fill_unambiguous_current_token_pointers!(
          connection,
          token_table:,
          device_table:,
        )
        verify_current_token_pointers!(
          connection,
          token_table:,
          device_table:,
          actor_column:,
        )

        migration.change_column_null(token_table, :device_session_id, false)

        bind_rp_sessions!(
          migration,
          token_table:,
          device_table:,
          rp_table:,
          token_parent_column:,
          old_active_index:,
          new_active_index:,
          rp_device_foreign_key:,
        )
      end
    end
  end

  def down(_migration)
    raise ActiveRecord::IrreversibleMigration,
          "device-session root and RP bindings are data-preserving and irreversible"
  end

  def verify_existing_token_bindings!(connection, token_table:, device_table:, actor_column:)
    token = quote_table(connection, token_table)
    device = quote_table(connection, device_table)
    actor = quote_column(connection, actor_column)

    rows = connection.select_values(<<~SQL.squish)
      SELECT t.id
        FROM #{token} AS t
        LEFT JOIN #{device} AS d ON d.id = t.device_session_id
       WHERE t.device_session_id IS NOT NULL
         AND (d.id IS NULL OR d.#{actor} IS DISTINCT FROM t.#{actor})
       ORDER BY t.id
    SQL
    raise_unresolved!("token/device-session bindings", rows)
  end

  def backfill_missing_token_bindings!(connection, token_table:, device_table:, actor_column:)
    token = quote_table(connection, token_table)
    device = quote_table(connection, device_table)
    actor = quote_column(connection, actor_column)
    sequence = connection.quote("#{device_table}_id_seq")
    map = "_device_session_root_binding_map"

    connection.execute(<<~SQL.squish)
      CREATE TEMP TABLE #{map} (
        token_id bigint PRIMARY KEY,
        device_session_id bigint NOT NULL UNIQUE
      ) ON COMMIT DROP
    SQL
    connection.execute(<<~SQL.squish)
      INSERT INTO #{map} (token_id, device_session_id)
      SELECT t.id, nextval(#{sequence}::regclass)
        FROM #{token} AS t
       WHERE t.device_session_id IS NULL
    SQL
    connection.execute(<<~SQL.squish)
      INSERT INTO #{device} (
        id,
        public_id,
        #{actor},
        status_id,
        current_refresh_token_id,
        refresh_token_family_id,
        last_seen_at,
        created_at,
        updated_at
      )
      SELECT m.device_session_id,
             REPLACE(REPLACE(SUBSTRING(ENCODE(gen_random_bytes(16), 'base64') FROM 1 FOR 21), '+', '-'), '/', '_'),
             t.#{actor},
             1,
             t.id,
             t.refresh_token_family_id,
             COALESCE(t.updated_at, t.created_at, CURRENT_TIMESTAMP),
             COALESCE(t.created_at, CURRENT_TIMESTAMP),
             COALESCE(t.updated_at, t.created_at, CURRENT_TIMESTAMP)
        FROM #{map} AS m
        JOIN #{token} AS t ON t.id = m.token_id
    SQL
    connection.execute(<<~SQL.squish)
      UPDATE #{token} AS t
         SET device_session_id = m.device_session_id
        FROM #{map} AS m
       WHERE t.id = m.token_id
    SQL
  end

  def verify_current_token_pointers!(connection, token_table:, device_table:, actor_column:)
    token = quote_table(connection, token_table)
    device = quote_table(connection, device_table)
    actor = quote_column(connection, actor_column)

    rows = connection.select_values(<<~SQL.squish)
      SELECT d.id
        FROM #{device} AS d
        LEFT JOIN #{token} AS t ON t.id = d.current_refresh_token_id
       WHERE d.current_refresh_token_id IS NOT NULL
         AND (
           t.id IS NULL
           OR t.device_session_id IS DISTINCT FROM d.id
           OR t.#{actor} IS DISTINCT FROM d.#{actor}
         )
       ORDER BY d.id
    SQL
    raise_unresolved!("current root-token pointers", rows)
  end

  def fill_unambiguous_current_token_pointers!(connection, token_table:, device_table:)
    token = quote_table(connection, token_table)
    device = quote_table(connection, device_table)

    rows = connection.select_values(<<~SQL.squish)
      SELECT d.id
        FROM #{device} AS d
        JOIN #{token} AS t ON t.device_session_id = d.id
       WHERE d.current_refresh_token_id IS NULL
       GROUP BY d.id
      HAVING COUNT(*) > 1
       ORDER BY d.id
    SQL
    raise_unresolved!("ambiguous current root-token pointers", rows)

    connection.execute(<<~SQL.squish)
      UPDATE #{device} AS d
         SET current_refresh_token_id = t.id,
             refresh_token_family_id = t.refresh_token_family_id,
             last_seen_at = COALESCE(t.updated_at, t.created_at, CURRENT_TIMESTAMP),
             updated_at = CURRENT_TIMESTAMP
        FROM #{token} AS t
       WHERE d.current_refresh_token_id IS NULL
         AND t.device_session_id = d.id
    SQL
  end

  def bind_rp_sessions!(
    migration,
    token_table:,
    device_table:,
    rp_table:,
    token_parent_column:,
    old_active_index:,
    new_active_index:,
    rp_device_foreign_key:
  )
    connection = migration.connection
    token = quote_table(connection, token_table)
    rp = quote_table(connection, rp_table)
    token_parent = quote_column(connection, token_parent_column)

    migration.add_column(rp_table, :device_session_id, :bigint) unless migration.column_exists?(
      rp_table,
      :device_session_id,
    )

    connection.execute(<<~SQL.squish)
      UPDATE #{rp} AS r
         SET device_session_id = t.device_session_id
        FROM #{token} AS t
       WHERE r.#{token_parent} = t.id
         AND r.device_session_id IS NULL
    SQL

    missing_rows = connection.select_values(<<~SQL.squish)
      SELECT r.id
        FROM #{rp} AS r
       WHERE r.device_session_id IS NULL
       ORDER BY r.id
    SQL
    raise_unresolved!("RP/device-session bindings", missing_rows)

    duplicate_rows = connection.select_values(<<~SQL.squish)
      SELECT device_session_id::text || ':' || oidc_client_id || ':' || STRING_AGG(id::text, ',')
        FROM #{rp}
       WHERE revoked_at IS NULL
       GROUP BY device_session_id, oidc_client_id
      HAVING COUNT(*) > 1
       ORDER BY device_session_id, oidc_client_id
    SQL
    raise_unresolved!("duplicate active RP Sessions", duplicate_rows)

    migration.add_foreign_key(
      rp_table,
      device_table,
      column: :device_session_id,
      name: rp_device_foreign_key,
      on_delete: :restrict,
      validate: false,
    )
    migration.validate_foreign_key(rp_table, name: rp_device_foreign_key)
    migration.change_column_null(rp_table, :device_session_id, false)

    migration.remove_index(rp_table, name: old_active_index)
    migration.add_index(
      rp_table,
      %i(device_session_id oidc_client_id),
      unique: true,
      where: "revoked_at IS NULL",
      name: new_active_index,
    )

    migration.remove_foreign_key(rp_table, column: token_parent_column)
  end

  def raise_unresolved!(description, ids)
    return if ids.empty?

    sample = ids.first(20).join(",")
    suffix = (ids.length > 20) ? ",... (#{ids.length} total)" : ""
    raise ActiveRecord::MigrationError,
          "unresolved #{description}; record identifiers: #{sample}#{suffix}"
  end
  private_class_method :raise_unresolved!

  def quote_table(connection, table)
    connection.quote_table_name(table)
  end
  private_class_method :quote_table

  def quote_column(connection, column)
    connection.quote_column_name(column)
  end
  private_class_method :quote_column
end
