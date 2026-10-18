# frozen_string_literal: true

require_relative "../../config/environment"
require "minitest/autorun"

class SchemaMigrationIfNotExistsTest < ActiveSupport::TestCase
  class Table
    attr_reader :columns

    def string(name, **options)
      @columns = [name, options]
    end
  end

  class Connection
    attr_reader :calls, :table
    attr_accessor :failure

    def initialize
      @calls = []
      @table = Table.new
    end

    def internal_string_options_for_primary_key
      { primary_key: true, collation: "C" }
    end

    def create_table(name, **options)
      @calls << [name, options]
      raise failure if failure

      yield table
      :created_or_already_present
    end
  end

  class Pool
    attr_reader :released

    def initialize(connection)
      @connection = connection
    end

    def with_connection
      yield @connection
    ensure
      @released = true
    end
  end

  def test_public_patch_forwards_idempotent_table_options_and_version_definition_on_every_call
    connection = Connection.new
    pool = Pool.new(connection)
    migration = ActiveRecord::SchemaMigration.new(pool)

    assert_equal SchemaMigrationIfNotExists, migration.method(:create_table).owner
    assert_respond_to migration, :create_table
    assert_empty migration.method(:create_table).parameters
    2.times do
      assert_equal :created_or_already_present, migration.create_table
    end
    assert_equal [[migration.table_name, { id: false, if_not_exists: true }]] * 2, connection.calls
    assert_equal [:version, { primary_key: true, collation: "C" }], connection.table.columns
    assert pool.released
    assert_raises(ArgumentError) { migration.create_table(:unexpected) }
  end

  def test_connection_errors_propagate_unchanged_and_connection_is_released
    connection = Connection.new
    connection.failure = ActiveRecord::StatementInvalid.new("DDL failed")
    pool = Pool.new(connection)

    error =
      assert_raises(ActiveRecord::StatementInvalid) do
        ActiveRecord::SchemaMigration.new(pool).create_table
      end

    assert_same connection.failure, error
    assert pool.released
  end
end
