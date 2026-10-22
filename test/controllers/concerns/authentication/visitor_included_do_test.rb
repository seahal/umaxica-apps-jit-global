# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class AuthenticationVisitorIncludedDoTest < ActiveSupport::TestCase
  class Harness < ApplicationController
    include AuthorizationAudit
    include AuthenticationVisitor
  end

  test "included do includes AuthenticationBase module" do
    assert_includes Harness.included_modules, AuthenticationBase
  end

  test "active_visitor? method exists" do
    assert_includes AuthenticationVisitor.instance_methods(false), :active_visitor?
  end

  test "audit_visitor_login_failed method exists" do
    assert_includes AuthenticationVisitor.instance_methods(false), :audit_visitor_login_failed
  end

  test "ACCESS_COOKIE_KEY constant is defined" do
    assert_equal AuthenticationBase::ACCESS_COOKIE_KEY, AuthenticationVisitor::ACCESS_COOKIE_KEY
  end

  test "REFRESH_COOKIE_KEY constant is defined" do
    assert_equal AuthenticationBase::REFRESH_COOKIE_KEY, AuthenticationVisitor::REFRESH_COOKIE_KEY
  end
end
