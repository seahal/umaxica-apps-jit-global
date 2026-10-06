# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class SignEmailRegistrableIncludedDoTest < ActiveSupport::TestCase
  class Harness < ApplicationController
    include CloudflareTurnstile
    include CommonRedirect
    include CommonOtp
    include SignEmailRegistrable
  end

  test "terminal controller includes CloudflareTurnstile explicitly" do
    assert_includes Harness.included_modules, CloudflareTurnstile
  end

  test "terminal controller includes CommonRedirect explicitly" do
    assert_includes Harness.included_modules, CommonRedirect
  end

  test "terminal controller includes CommonOtp explicitly" do
    assert_includes Harness.included_modules, CommonOtp
  end

  test "SESSION_KEY constant is defined" do
    assert_equal :sign_up_email_flow_state, SignEmailRegistrable::SESSION_KEY
  end

  test "the signup flow does not carry a cross-flow existing-email session key" do
    assert_not_includes SignEmailRegistrable.constants, :EXISTING_EMAIL_SESSION_KEY
  end

  test "STATE_INIT constant is defined" do
    assert_equal "init", SignEmailRegistrable::STATE_INIT
  end

  test "VALID_STATES constant is defined" do
    assert_kind_of Array, SignEmailRegistrable::VALID_STATES
  end
end
