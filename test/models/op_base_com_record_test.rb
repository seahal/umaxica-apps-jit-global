# typed: false
# frozen_string_literal: true

require "test_helper"

class OpBaseComRecordTest < ActiveSupport::TestCase
  test "should be abstract class" do
    assert_predicate OpBaseComRecord, :abstract_class?
  end

  test "should inherit from ApplicationRecord" do
    assert_operator OpBaseComRecord, :<, ApplicationRecord
  end

  test "should connect to op_base_com database" do
    assert_respond_to OpBaseComRecord, :connection_db_config
  end
end
