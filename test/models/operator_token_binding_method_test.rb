# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: operator_token_binding_methods
# Database name: op_base_org
#
#  id :bigint           not null, primary key
#
require "test_helper"

class OperatorTokenBindingMethodTest < ActiveSupport::TestCase
  test "constants are defined correctly" do
    assert_equal 0, OperatorTokenBindingMethod::NOTHING
    assert_equal 1, OperatorTokenBindingMethod::DBSC
    assert_equal 2, OperatorTokenBindingMethod::LEGACY
    assert_equal [0, 1, 2], OperatorTokenBindingMethod::DEFAULTS
  end

  test "ensure_defaults! creates missing records" do
    Prosopite.pause do
      OperatorTokenBindingMethod.where(id: OperatorTokenBindingMethod::DEFAULTS).destroy_all
    end

    OperatorTokenBindingMethod.ensure_defaults!

    assert OperatorTokenBindingMethod.exists?(id: OperatorTokenBindingMethod::NOTHING)
    assert OperatorTokenBindingMethod.exists?(id: OperatorTokenBindingMethod::DBSC)
    assert OperatorTokenBindingMethod.exists?(id: OperatorTokenBindingMethod::LEGACY)
  end

  test "ensure_defaults! does nothing when all defaults exist" do
    OperatorTokenBindingMethod.ensure_defaults!
    initial_count = OperatorTokenBindingMethod.count

    OperatorTokenBindingMethod.ensure_defaults!

    assert_equal initial_count, OperatorTokenBindingMethod.count
  end

  test "has_many operator_tokens association" do
    method = OperatorTokenBindingMethod.new(id: 1)

    assert_respond_to method, :operator_tokens
  end
end
