# typed: false
# frozen_string_literal: true

require "test_helper"

class IdColumnTypeTest < ActiveSupport::TestCase
  test "roles and memberships use bigint foreign keys" do
    assert_bigint_table_column(AppPrincipalRecord.connection, :roles, "organization_id")
    assert_bigint_column(ClientMembership, "workspace_id")
  end

  test "notification public_id columns are strings" do
    [
      ClientNotificationRecord,
      OperatorNotificationRecord,
      MemberNotification,
      OperatorNotification,
    ].each do |model|
      assert_string_column(model, "public_id")
    end
  end

  private

  def assert_bigint_column(model, column_name)
    column = model.columns_hash[column_name]

    assert column, "#{model.name} should have #{column_name}"
    assert_equal :integer, column.type, "#{model.name}.#{column_name} should be :integer"
    assert_equal 8, column.limit, "#{model.name}.#{column_name} should be bigint (limit: 8)"
  end

  def assert_string_column(model, column_name)
    column = model.columns_hash[column_name]

    assert column, "#{model.name} should have #{column_name}"
    assert_equal :string, column.type, "#{model.name}.#{column_name} should be :string"
  end

  def assert_bigint_table_column(connection, table_name, column_name)
    column = connection.columns(table_name).find { |col| col.name == column_name }

    assert column, "#{table_name}.#{column_name} should exist"
    assert_equal :integer, column.type, "#{table_name}.#{column_name} should be :integer"
    assert_equal 8, column.limit, "#{table_name}.#{column_name} should be bigint (limit: 8)"
  end
end
