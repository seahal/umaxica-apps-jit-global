# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: operator_token_kinds
# Database name: op_base_org
#
#  id :bigint           not null, primary key
#

require "test_helper"

class OperatorTokenKindTest < ActiveSupport::TestCase
  test "accepts integer ids" do
    kind = OperatorTokenKind.new(id: 99)

    assert_predicate kind, :valid?
  end

  test "constants are defined" do
    assert_equal 1, OperatorTokenKind::BROWSER_WEB
    assert_equal 2, OperatorTokenKind::CLIENT_IOS
    assert_equal 3, OperatorTokenKind::CLIENT_ANDROID
  end

  test "defaults are defined" do
    assert_equal [1, 2, 3], OperatorTokenKind::DEFAULTS
  end

  test "has many staff_tokens" do
    assert_equal :has_many, OperatorTokenKind.reflect_on_association(:staff_tokens).macro
  end
end
