# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class AuthenticationClientIncludedDoTest < ActiveSupport::TestCase
  class Harness < ApplicationController
    include AuthorizationAudit
    include AuthenticationClient
  end

  test "included do includes AuthenticationBase module" do
    assert_includes Harness.included_modules, AuthenticationBase
  end

  test "active_client? method exists" do
    assert_includes AuthenticationClient.instance_methods(false), :active_client?
  end

  test "audit_client_login_failed method exists" do
    assert_includes AuthenticationClient.instance_methods(false), :audit_client_login_failed
  end

  test "ACCESS_COOKIE_KEY constant is defined" do
    assert_equal AuthenticationBase::ACCESS_COOKIE_KEY, AuthenticationClient::ACCESS_COOKIE_KEY
  end

  test "REFRESH_COOKIE_KEY constant is defined" do
    assert_equal AuthenticationBase::REFRESH_COOKIE_KEY, AuthenticationClient::REFRESH_COOKIE_KEY
  end
end
