# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class AuthenticationOperatorIncludedDoTest < ActiveSupport::TestCase
  class Harness < ApplicationController
    include AuthorizationAudit
    include AuthenticationOperator
  end

  test "included do includes AuthenticationBase module" do
    assert_includes Harness.included_modules, AuthenticationBase
  end

  test "included do does not register refresh callback" do
    refresh_callbacks =
      Harness._process_action_callbacks.select { |callback|
        callback.kind == :before && callback.filter == :transparent_refresh_access_token
      }

    assert_empty refresh_callbacks
  end

  test "active_operator? method exists" do
    assert_includes AuthenticationOperator.instance_methods(false), :active_operator?
  end

  test "audit_operator_login_failed method exists" do
    assert_includes AuthenticationOperator.instance_methods(false), :audit_operator_login_failed
  end

  test "ACCESS_COOKIE_KEY constant is defined" do
    assert_equal AuthenticationBase::ACCESS_COOKIE_KEY, AuthenticationOperator::ACCESS_COOKIE_KEY
  end

  test "REFRESH_COOKIE_KEY constant is defined" do
    assert_equal AuthenticationBase::REFRESH_COOKIE_KEY, AuthenticationOperator::REFRESH_COOKIE_KEY
  end
end
