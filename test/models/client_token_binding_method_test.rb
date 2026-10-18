# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: client_token_binding_methods
# Database name: op_base_app
#
#  id :bigint           not null, primary key
#
require "test_helper"

class ClientTokenBindingMethodTest < ActiveSupport::TestCase
  test "constants are defined correctly" do
    assert_equal 0, ClientTokenBindingMethod::NOTHING
    assert_equal 1, ClientTokenBindingMethod::DBSC
    assert_equal 2, ClientTokenBindingMethod::LEGACY
    assert_equal [0, 1, 2], ClientTokenBindingMethod::DEFAULTS
  end

  test "ensure_defaults! creates missing records" do
    Prosopite.pause do
      ClientTokenBindingMethod.where(id: ClientTokenBindingMethod::DEFAULTS).destroy_all
    end

    ClientTokenBindingMethod.ensure_defaults!

    assert ClientTokenBindingMethod.exists?(id: ClientTokenBindingMethod::NOTHING)
    assert ClientTokenBindingMethod.exists?(id: ClientTokenBindingMethod::DBSC)
    assert ClientTokenBindingMethod.exists?(id: ClientTokenBindingMethod::LEGACY)
  end

  test "ensure_defaults! does nothing when all defaults exist" do
    ClientTokenBindingMethod.ensure_defaults!
    initial_count = ClientTokenBindingMethod.count

    ClientTokenBindingMethod.ensure_defaults!

    assert_equal initial_count, ClientTokenBindingMethod.count
  end

  test "has_many client_tokens association" do
    method = ClientTokenBindingMethod.new(id: 1)

    assert_respond_to method, :client_tokens
  end
end
