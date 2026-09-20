# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class SignComVerificationBaseIncludedDoTest < ActiveSupport::TestCase
  test "included do does not include SignAppVerificationBase module" do
    klass =
      Class.new(ApplicationController) do
        include AuthenticationBase
        include PreferenceBase
        include AuthenticationVisitor
        include VerificationVisitor
        include SignEmailOtpVerificationSupport
        include SignComVerificationBase
      end

    assert_not_includes klass.included_modules, SignAppVerificationBase
  end

  test "included do includes visitor verification dependencies directly" do
    klass =
      Class.new(ApplicationController) do
        include AuthenticationBase
        include PreferenceBase
        include AuthenticationVisitor
        include VerificationVisitor
        include SignEmailOtpVerificationSupport
        include SignComVerificationBase
      end

    assert_includes klass.included_modules, AuthenticationVisitor
    assert_includes klass.included_modules, VerificationVisitor
    assert_includes klass.included_modules, SignEmailOtpVerificationSupport
  end
end
