# frozen_string_literal: true

# Safely replaces each token's single-column device-session index with the
# composite unique index required by the session's current-token foreign key.
module DeviceSessionTokenIndexes
  LOCK_TIMEOUT = "5s"
  STATEMENT_TIMEOUT = "30min"

  def self.ensure_actor_reference_index!(migration, table:, index_name:, actor_column:)
    columns = [actor_column.to_s, "id"]
    with_timeouts(migration.connection) do
      state = index_state(migration.connection, table:, index_name:)
      raise_unexpected_index!(table, index_name) if state && !index_shape_matches?(state, unique: true, columns:)
      return if state && index_usable?(state)

      migration.remove_index(table, name: index_name, algorithm: :concurrently) if state
      migration.add_index(table, columns, name: index_name, unique: true, algorithm: :concurrently)

      state = index_state(migration.connection, table:, index_name:)
      return if state && index_shape_matches?(state, unique: true, columns:) && index_usable?(state)

      raise ActiveRecord::MigrationError, "#{index_name} was not created as a valid unique btree on #{table}"
    end
  end

  def self.remove_actor_reference_index!(migration, table:, index_name:, actor_column:)
    columns = [actor_column.to_s, "id"]
    with_timeouts(migration.connection) do
      state = index_state(migration.connection, table:, index_name:)
      raise ActiveRecord::MigrationError, "#{index_name} is missing" unless state

      raise_unexpected_index!(table, index_name) unless index_shape_matches?(state, unique: true, columns:)

      migration.remove_index(table, name: index_name, algorithm: :concurrently)
    end
  end

  def self.up(migration, table:, index_name:, old_index_name:)
    connection = migration.connection

    with_timeouts(connection) do
      old_state = index_state(connection, table:, index_name: old_index_name)
      new_state = index_state(connection, table:, index_name:)
      if old_state.nil? && !composite_index_usable?(new_state)
        raise ActiveRecord::MigrationError,
              "#{old_index_name} is missing before its valid replacement #{index_name} exists"
      end

      if old_state && !single_column_index_shape_matches?(old_state, unique: false)
        raise_unexpected_index!(table, old_index_name)
      end

      ensure_index!(migration, table:, index_name:)
      remove_old_index!(migration, table:, index_name:, old_index_name:)
    end
  end

  def self.down(migration, table:, index_name:, old_index_name:)
    connection = migration.connection

    with_timeouts(connection) do
      old_state = index_state(connection, table:, index_name: old_index_name)
      new_state = index_state(connection, table:, index_name:)
      if old_state.nil? && new_state.nil?
        raise ActiveRecord::MigrationError,
              "both #{old_index_name} and #{index_name} are missing; refusing to guess the prior index state"
      end

      if old_state && !single_column_index_shape_matches?(old_state, unique: false)
        raise_unexpected_index!(table, old_index_name)
      end
      if new_state && !composite_index_shape_matches?(new_state)
        raise_unexpected_index!(table, index_name)
      end

      ensure_old_index!(migration, table:, old_index_name:)
      remove_composite_index!(migration, table:, index_name:)
    end
  end

  def self.with_timeouts(connection)
    previous = connection.select_one(<<~SQL.squish)
      SELECT current_setting('lock_timeout') AS lock_timeout,
             current_setting('statement_timeout') AS statement_timeout
    SQL

    connection.execute("SET lock_timeout = '#{LOCK_TIMEOUT}'")
    connection.execute("SET statement_timeout = '#{STATEMENT_TIMEOUT}'")
    yield
  ensure
    if previous
      connection.execute("SET lock_timeout = #{connection.quote(previous.fetch("lock_timeout"))}")
      connection.execute("SET statement_timeout = #{connection.quote(previous.fetch("statement_timeout"))}")
    end
  end
  private_class_method :with_timeouts

  def self.ensure_index!(migration, table:, index_name:)
    state = index_state(migration.connection, table:, index_name:)
    if state
      raise_unexpected_index!(table, index_name) unless composite_index_shape_matches?(state)
      return if index_usable?(state)

      migration.remove_index(table, name: index_name, algorithm: :concurrently)
    end

    migration.add_index(
      table,
      %i(device_session_id id),
      name: index_name,
      unique: true,
      algorithm: :concurrently,
    )

    state = index_state(migration.connection, table:, index_name:)
    return if composite_index_usable?(state)

    raise ActiveRecord::MigrationError,
          "#{index_name} was not created as a valid unique btree on #{table}(device_session_id, id)"
  end
  private_class_method :ensure_index!

  def self.remove_old_index!(migration, table:, index_name:, old_index_name:)
    state = index_state(migration.connection, table:, index_name: old_index_name)
    return unless state

    unless single_column_index_shape_matches?(state, unique: false)
      raise_unexpected_index!(table, old_index_name)
    end

    replacement = index_state(migration.connection, table:, index_name:)
    unless composite_index_usable?(replacement)
      raise ActiveRecord::MigrationError, "#{index_name} must be valid before replacing #{old_index_name}"
    end

    migration.remove_index(table, name: old_index_name, algorithm: :concurrently)
  end
  private_class_method :remove_old_index!

  def self.ensure_old_index!(migration, table:, old_index_name:)
    state = index_state(migration.connection, table:, index_name: old_index_name)
    if state
      raise_unexpected_index!(table, old_index_name) unless single_column_index_shape_matches?(state, unique: false)
      return if index_usable?(state)

      migration.remove_index(table, name: old_index_name, algorithm: :concurrently)
    end

    migration.add_index(table, :device_session_id, name: old_index_name, algorithm: :concurrently)
    state = index_state(migration.connection, table:, index_name: old_index_name)
    return if single_column_index_usable?(state, unique: false)

    raise ActiveRecord::MigrationError,
          "#{old_index_name} was not recreated as a valid btree on #{table}(device_session_id)"
  end
  private_class_method :ensure_old_index!

  def self.remove_composite_index!(migration, table:, index_name:)
    state = index_state(migration.connection, table:, index_name:)
    return unless state

    unless composite_index_shape_matches?(state)
      raise_unexpected_index!(table, index_name)
    end

    migration.remove_index(table, name: index_name, algorithm: :concurrently)
  end
  private_class_method :remove_composite_index!

  def self.index_state(connection, table:, index_name:)
    connection.select_one(<<~SQL.squish)
      SELECT index_method.amname AS access_method,
             index_data.indisunique AS is_unique,
             index_data.indisprimary AS is_primary,
             index_data.indnullsnotdistinct AS nulls_not_distinct,
             index_data.indisvalid AS is_valid,
             index_data.indisready AS is_ready,
             index_data.indnkeyatts AS key_count,
             index_data.indnatts AS attribute_count,
             index_data.indexprs IS NULL AS has_no_expressions,
             index_data.indpred IS NULL AS has_no_predicate,
             pg_catalog.pg_get_indexdef(index_class.oid, 1, true) AS first_key,
             CASE WHEN index_data.indnatts >= 2
               THEN pg_catalog.pg_get_indexdef(index_class.oid, 2, true)
             END AS second_key
        FROM pg_catalog.pg_class AS index_class
        JOIN pg_catalog.pg_namespace AS index_namespace ON index_namespace.oid = index_class.relnamespace
        JOIN pg_catalog.pg_index AS index_data ON index_data.indexrelid = index_class.oid
        JOIN pg_catalog.pg_class AS table_class ON table_class.oid = index_data.indrelid
        JOIN pg_catalog.pg_namespace AS table_namespace ON table_namespace.oid = table_class.relnamespace
        JOIN pg_catalog.pg_am AS index_method ON index_method.oid = index_class.relam
       WHERE index_namespace.nspname = current_schema()
         AND table_namespace.nspname = current_schema()
         AND table_class.relname = #{connection.quote(table.to_s)}
         AND index_class.relname = #{connection.quote(index_name)}
    SQL
  end
  private_class_method :index_state

  def self.index_shape_matches?(state, unique:, columns:)
    boolean(state.fetch("is_unique")) == unique &&
      !boolean(state.fetch("is_primary")) &&
      !boolean(state.fetch("nulls_not_distinct")) &&
      state.fetch("access_method") == "btree" &&
      state.fetch("key_count").to_i == columns.length &&
      state.fetch("attribute_count").to_i == columns.length &&
      boolean(state.fetch("has_no_expressions")) &&
      boolean(state.fetch("has_no_predicate")) &&
      columns.each_with_index.all? { |column, index| state.fetch(index.zero? ? "first_key" : "second_key") == column }
  end
  private_class_method :index_shape_matches?

  def self.index_usable?(state)
    boolean(state.fetch("is_valid")) && boolean(state.fetch("is_ready"))
  end
  private_class_method :index_usable?

  def self.composite_index_shape_matches?(state)
    state && index_shape_matches?(state, unique: true, columns: %w(device_session_id id))
  end
  private_class_method :composite_index_shape_matches?

  def self.composite_index_usable?(state)
    composite_index_shape_matches?(state) && index_usable?(state)
  end
  private_class_method :composite_index_usable?

  def self.single_column_index_shape_matches?(state, unique:)
    state && index_shape_matches?(state, unique:, columns: %w(device_session_id))
  end
  private_class_method :single_column_index_shape_matches?

  def self.single_column_index_usable?(state, unique:)
    single_column_index_shape_matches?(state, unique:) && index_usable?(state)
  end
  private_class_method :single_column_index_usable?

  def self.boolean(value)
    value == true || value == "t"
  end
  private_class_method :boolean

  def self.raise_unexpected_index!(table, index_name)
    raise ActiveRecord::MigrationError,
          "#{index_name} on #{table} has an unexpected definition; inspect it before retrying this migration"
  end
  private_class_method :raise_unexpected_index!
end
