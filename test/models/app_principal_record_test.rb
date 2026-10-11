# typed: false
# frozen_string_literal: true

require "test_helper"

class AppPrincipalRecordTest < ActiveSupport::TestCase
  test "should be abstract class" do
    assert_predicate AppPrincipalRecord, :abstract_class?
  end

  test "should inherit from ApplicationRecord" do
    assert_operator AppPrincipalRecord, :<, ApplicationRecord
  end

  test "uses the consolidated app zenith database" do
    assert_equal "app_zenith", AppPrincipalRecord.connection_db_config.name
    assert_equal AppRpRecord.connection_db_config.name, AppPrincipalRecord.connection_db_config.name
  end

  test "should connect to identifier database for writing and reading" do
    assert_respond_to AppPrincipalRecord, :connection
    assert_respond_to AppPrincipalRecord, :connected?
  end

  test "should not be instantiable as abstract class" do
    assert_raises(NotImplementedError) do
      AppPrincipalRecord.new
    end
  end

  test "should have proper database connection specification" do
    writing_config = AppPrincipalRecord.connection_specification_name

    assert_not_nil writing_config
  end

  test "should inherit all ActiveRecord functionality" do
    assert_respond_to AppPrincipalRecord, :table_name
    assert_respond_to AppPrincipalRecord, :primary_key
    assert_respond_to AppPrincipalRecord, :find_by_sql
    assert_respond_to AppPrincipalRecord, :transaction
  end

  test "shares the app zenith writer pool with the rp semantic base" do
    assert_equal AppRpRecord.connection_specification_name, AppPrincipalRecord.connection_specification_name
    assert_same AppRpRecord.connection_pool, AppPrincipalRecord.connection_pool
  end

  test "should support encryption functionality" do
    # Since this is the base class for models with encrypted fields
    assert_respond_to AppPrincipalRecord, :encrypts
  end

  test "should support UUID primary keys" do
    # Many identifier models use UUIDs
    assert_respond_to AppPrincipalRecord, :primary_key
  end
end
