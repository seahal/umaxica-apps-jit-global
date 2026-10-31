# typed: false
# frozen_string_literal: true

require "test_helper"

class CoverageClientAuthHarness < ApplicationController
  include AuthenticationClient

  attr_accessor :resource

  def current_resource = resource

  def authenticate! = (@authenticated = true)

  def record_audit(*) = (@audit_recorded = true)
end

class CoverageOperatorAuthHarness < ApplicationController
  include AuthenticationOperator

  attr_accessor :resource

  def current_resource = resource

  def authenticate! = (@authenticated = true)

  def record_audit(*) = (@audit_recorded = true)
end

class CoverageThresholdAuthenticationHelpersTest < ActiveSupport::TestCase
  def active_double(active)
    Object.new.tap do |object|
      object.define_singleton_method(:active?) { active }
    end
  end

  test "client authentication concern exposes current and active client predicates" do
    harness = CoverageClientAuthHarness.new

    assert_nil harness.current_client
    assert_not_predicate harness, :logged_in_client?
    assert_not_predicate harness, :active_client?
    harness.resource = active_double(true)

    assert_same harness.resource, harness.current_client
    assert_predicate harness, :logged_in_client?
    assert_predicate harness, :active_client?
    assert_predicate harness, :am_i_client?
    assert_not_predicate harness, :am_i_staff?
    assert_not_predicate harness, :am_i_owner?
  end

  test "operator authentication concern exposes current and active operator predicates" do
    harness = CoverageOperatorAuthHarness.new

    assert_nil harness.current_operator
    assert_not_predicate harness, :logged_in_operator?
    assert_not_predicate harness, :active_operator?
    harness.resource = active_double(true)

    assert_same harness.resource, harness.current_operator
    assert_predicate harness, :logged_in_operator?
    assert_predicate harness, :active_operator?
    assert_not_predicate harness, :am_i_user?
    assert_predicate harness, :am_i_operator?
    assert_not_predicate harness, :am_i_owner?
  end

end
