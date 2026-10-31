# frozen_string_literal: true

require "test_helper"

class DeadIdentifierHistoryContractTest < ActiveSupport::TestCase
  test "each email history contains only identity fingerprint and lifecycle facts" do
    [ClientEmailHistory,
     OperatorEmailHistory,].zip(%w(user_id staff_id)).each do |model, owner_key|
      assert_equal %W(id #{owner_key} fingerprint attached_at detached_at created_at).sort, model.column_names.sort
      assert_not model.connection.indexes(model.table_name).any? { |index| index.columns == ["fingerprint"] }
      assert_not model.connection.indexes(model.table_name).any? { |index|
        index.unique && index.columns.include?("fingerprint")
      }
    end
  end

  test "each telephone history contains only identity fingerprint and lifecycle facts" do
    [ClientTelephoneHistory,
     OperatorTelephoneHistory,].zip(%w(user_id staff_id)).each do |model, owner_key|
      assert_equal %W(id #{owner_key} fingerprint attached_at detached_at created_at).sort, model.column_names.sort
      assert_not model.connection.indexes(model.table_name).any? { |index| index.columns == ["fingerprint"] }
      assert_not model.connection.indexes(model.table_name).any? { |index|
        index.unique && index.columns.include?("fingerprint")
      }
    end
  end
end
