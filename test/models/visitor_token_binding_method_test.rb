# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: visitor_token_binding_methods
# Database name: op_base_com
#
#  id :bigint           not null, primary key
#

require "test_helper"

class VisitorTokenBindingMethodTest < ActiveSupport::TestCase
  test "constants are defined" do
    assert_equal 0, VisitorTokenBindingMethod::NOTHING
    assert_equal 1, VisitorTokenBindingMethod::DBSC
    assert_equal 2, VisitorTokenBindingMethod::LEGACY
  end

  test "defaults are defined" do
    assert_equal [0, 1, 2], VisitorTokenBindingMethod::DEFAULTS
  end

  test "nothing_id returns NOTHING constant" do
    assert_equal VisitorTokenBindingMethod::NOTHING, VisitorTokenBindingMethod.nothing_id
  end

  test "has many visitor_tokens" do
    assert_equal :has_many, VisitorTokenBindingMethod.reflect_on_association(:visitor_tokens).macro
  end
end
