# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class AuthenticationBaseExtractionTest < ActiveSupport::TestCase
  class Harness < ApplicationController
    include AuthenticationBase
  end

  test "base includes extracted authentication concerns" do
    assert_includes Harness.included_modules, AuthenticationRedirects
    assert_includes Harness.included_modules, AuthenticationCookieStore
    assert_includes Harness.included_modules, AuthenticationJwtTokens
    assert_includes Harness.included_modules, AuthenticationBulletinGate
    assert_includes Harness.included_modules, AuthenticationSequenceGate
    assert_includes Harness.included_modules, AuthenticationWithdrawalGate
  end

  test "extracted public methods remain public on controllers" do
    assert_operator Harness.public_instance_methods, :include?, :set_login_auth_cookies
    assert_operator Harness.public_instance_methods, :include?, :encode_login_access_token
    assert_operator Harness.public_instance_methods, :include?, :issue_bulletin!
    assert_operator Harness.public_instance_methods, :include?, :sign_in_sequence_redirect_path
  end

  test "extracted concerns do not register process callbacks" do
    filters = Harness._process_action_callbacks.map(&:filter)

    assert_not_includes filters, :set_login_auth_cookies
    assert_not_includes filters, :encode_login_access_token
    assert_not_includes filters, :issue_bulletin!
    assert_not_includes filters, :sign_in_sequence_redirect_path
  end
end
