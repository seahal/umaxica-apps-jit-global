# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class SignAppVerificationBaseIncludedDoTest < ActiveSupport::TestCase
  class Harness < ApplicationController
    include PreferenceGlobal
    include CommonOtp
    include VerificationClient
    include PasskeyCeremonyContext
    include SignVerificationTiming
    include SignVerificationCommonBase
    include SignVerificationAuditAndCookie
    include SignVerificationStepUpSessionStore
    include SignVerificationStepUpLifecycle
    include SignVerificationPasskeyChecks
    include SignVerificationTotpChecks
    include SignAppVerificationBase
  end

  test "included do includes PreferenceGlobal module" do
    assert_includes Harness.included_modules, PreferenceGlobal
  end

  test "included do includes CommonOtp module" do
    assert_includes Harness.included_modules, CommonOtp
  end

  test "included do includes VerificationClient module" do
    assert_includes Harness.included_modules, VerificationClient
  end

  test "included do includes PasskeyCeremonyContext module" do
    assert_includes Harness.included_modules, PasskeyCeremonyContext
  end

  test "included do includes SignVerificationTiming module" do
    assert_includes Harness.included_modules, SignVerificationTiming
  end

  test "included do includes SignVerificationCommonBase module" do
    assert_includes Harness.included_modules, SignVerificationCommonBase
  end

  test "included do includes SignVerificationAuditAndCookie module" do
    assert_includes Harness.included_modules, SignVerificationAuditAndCookie
  end

  test "included do includes SignVerificationStepUpSessionStore module" do
    assert_includes Harness.included_modules, SignVerificationStepUpSessionStore
  end

  test "included do includes SignVerificationStepUpLifecycle module" do
    assert_includes Harness.included_modules, SignVerificationStepUpLifecycle
  end

  test "included do includes SignVerificationPasskeyChecks module" do
    assert_includes Harness.included_modules, SignVerificationPasskeyChecks
  end

  test "included do includes SignVerificationTotpChecks module" do
    assert_includes Harness.included_modules, SignVerificationTotpChecks
  end

  test "STEP_UP_TTL constant is defined" do
    assert_equal 15.minutes, SignAppVerificationBase::STEP_UP_TTL
  end

  test "ALLOWED_SCOPES constant is defined" do
    assert_kind_of Hash, SignAppVerificationBase::ALLOWED_SCOPES
    assert SignAppVerificationBase::ALLOWED_SCOPES.key?("settings_email")
    assert SignAppVerificationBase::ALLOWED_SCOPES.key?("settings_telephone")
  end
end
