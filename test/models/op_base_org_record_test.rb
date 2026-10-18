# typed: false
# frozen_string_literal: true

require "test_helper"

class OpBaseOrgRecordTest < ActiveSupport::TestCase
  test "should be abstract class" do
    assert_predicate OpBaseOrgRecord, :abstract_class?
  end

  test "should inherit from ApplicationRecord" do
    assert_operator OpBaseOrgRecord, :<, ApplicationRecord
  end

  test "should connect to op_base_org database" do
    assert_respond_to OpBaseOrgRecord, :connection_db_config
  end
end
