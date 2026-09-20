# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class SignOrgVerificationBaseIncludedDoTest < ActiveSupport::TestCase
  class Harness < ApplicationController
    include PreferenceGlobal
    include CommonOtp
    include AuthenticationOperator
    include VerificationOperator
    include PasskeyCeremonyContext
    include SignVerificationTiming
    include SignVerificationCommonBase
    include SignVerificationAuditAndCookie
    include SignVerificationStepUpSessionStore
    include SignVerificationStepUpLifecycle
    include SignVerificationPasskeyChecks
    include SignOrgVerificationBase
  end

  test "included do includes PreferenceGlobal module" do
    assert_includes Harness.included_modules, PreferenceGlobal
  end

  test "included do includes CommonOtp module" do
    assert_includes Harness.included_modules, CommonOtp
  end

  test "included do includes AuthenticationOperator module" do
    assert_includes Harness.included_modules, AuthenticationOperator
  end

  test "included do includes VerificationOperator module" do
    assert_includes Harness.included_modules, VerificationOperator
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

  test "STEP_UP_TTL constant is defined" do
    assert_equal 15.minutes, SignOrgVerificationBase::STEP_UP_TTL
  end

  test "ALLOWED_SCOPES constant is defined" do
    assert_kind_of Hash, SignOrgVerificationBase::ALLOWED_SCOPES
    assert SignOrgVerificationBase::ALLOWED_SCOPES.key?("settings_passkey")
    assert SignOrgVerificationBase::ALLOWED_SCOPES.key?("settings_mfa")
  end
end

# Direct coverage of VerificationBase itself, exercised through the Org/Operator surface.
#
# The full Harness above pulls in SignVerificationStepUpLifecycle, SignVerificationAuditAndCookie,
# and friends, several of which declare their own abstract (NotImplementedError-raising)
# verification_model / current_verification_actor stand-ins that sit ahead of VerificationBase in the
# module chain and shadow it -- so calls against that Harness cannot reach VerificationBase's own
# code for those methods. This class instead builds a controller with only VerificationOperator
# (VerificationBase + actor_operator? == true, no further overrides), which reaches VerificationBase's
# own method bodies directly for every call below.
#
# Rendering: assigning a fresh ActionDispatch::TestResponse to a controller that was never dispatched
# through #process already reports #performed? as true in this app's Rails version, so a real
# render/redirect_to call here always raises AbstractController::DoubleRenderError regardless of what
# preceded it. Tests that need to observe a render/redirect stub the method via
# define_singleton_method and assert on the captured arguments instead, matching the existing pattern
# in test/controllers/concerns/authentication/base_coverage_test.rb.
class SignOrgVerificationBaseDirectCoverageTest < ActiveSupport::TestCase
  test "verification_satisfied? returns false when there is no actor token" do
    harness = build_verification_base_harness
    harness.define_singleton_method(:current_session) { nil }
    harness.define_singleton_method(:current_session_public_id) { nil }

    assert_not harness.send(:verification_satisfied?)
  end

  test "verification_satisfied? delegates to the verification cookie record when no step-up scope is required" do
    staff = operators(:one)
    token = OperatorToken.create!(staff: staff)
    _verification, raw_token = OperatorVerification.issue_for_token!(token: token)
    harness = build_verification_base_harness
    harness.define_singleton_method(:current_session) { nil }
    harness.define_singleton_method(:current_session_public_id) { token.public_id }
    harness.send(:cookies)[OperatorVerification.cookie_name] = raw_token

    assert harness.send(:verification_satisfied?)
  end

  test "verification_record_satisfied? returns false when the verification cookie is missing" do
    staff = operators(:one)
    token = OperatorToken.create!(staff: staff)
    harness = build_verification_base_harness

    assert_not harness.send(:verification_record_satisfied?, token)
  end

  test "verification_record_satisfied? returns false when the cookie does not match a verification record" do
    staff = operators(:one)
    token = OperatorToken.create!(staff: staff)
    harness = build_verification_base_harness
    harness.send(:cookies)[OperatorVerification.cookie_name] = "not-a-real-token"

    assert_not harness.send(:verification_record_satisfied?, token)
  end

  test "verification_record_satisfied? returns true and stamps last_used_at when the cookie matches" do
    staff = operators(:one)
    token = OperatorToken.create!(staff: staff)
    _verification, raw_token = OperatorVerification.issue_for_token!(token: token)
    harness = build_verification_base_harness
    harness.send(:cookies)[OperatorVerification.cookie_name] = raw_token

    assert harness.send(:verification_record_satisfied?, token)
    assert_in_delta Time.current, OperatorVerification.active.find_by!(staff_token_id: token.id).last_used_at, 5.seconds
  end

  test "require_step_up! returns nil without side effects when step-up is already satisfied" do
    staff = operators(:one)
    token = OperatorToken.create!(staff: staff)
    harness = build_verification_base_harness
    harness.define_singleton_method(:current_session_token) { token }
    harness.define_singleton_method(:step_up_satisfied?) { |**| true }

    assert_nil harness.send(:require_step_up!, scope: :settings_passkey)
  end

  test "require_step_up! returns false immediately when the step-up session is revoked" do
    harness = build_verification_base_harness
    harness.define_singleton_method(:current_session_token) { nil }

    assert_not harness.send(:require_step_up!, scope: :settings_passkey)
  end

  test "require_step_up! redirects to the verification path for a GET request when step-up is not satisfied" do
    staff = operators(:one)
    token = OperatorToken.create!(staff: staff)
    harness = build_verification_base_harness
    harness.define_singleton_method(:current_session_token) { token }
    harness.define_singleton_method(:enforce_step_up_prereqs!) { |**| true }
    redirected = nil
    harness.define_singleton_method(:redirect_to) { |*args, **kwargs| redirected = [args, kwargs] }

    result = harness.send(:require_step_up!, scope: :settings_passkey)

    assert_not result
    assert_match %r{/verification\?}, redirected[0][0]
  ensure
    Actor.reset
  end

  test "require_step_up! logs the installed step-up context including a computed expiry" do
    staff = operators(:one)
    token = OperatorToken.create!(staff: staff)
    token.update_columns(last_step_up_at: 1.minute.ago, last_step_up_scope: "unrelated_scope")
    harness = build_verification_base_harness
    harness.define_singleton_method(:current_session_token) { token }
    harness.define_singleton_method(:enforce_step_up_prereqs!) { |**| true }
    harness.define_singleton_method(:redirect_to) { |*, **| nil }

    result = harness.send(:require_step_up!, scope: :settings_passkey)

    assert_not result
    assert_predicate Actor.step_up.expires_at, :present?
  ensure
    Actor.reset
  end

  private

  def build_verification_base_harness
    harness = Class.new(ApplicationController) { include VerificationOperator }.new
    harness.request = ActionDispatch::TestRequest.create
    harness.response = ActionDispatch::TestResponse.new
    # The minimal VerificationOperator-only harness has no AuthenticationOperator, so
    # current_session_public_id/token_class (referenced unconditionally, not behind a respond_to?
    # guard, by several VerificationBase methods) would otherwise raise NameError. Tests that care
    # about a specific public id/session override these again afterwards.
    harness.define_singleton_method(:current_session_public_id) { nil }
    harness.define_singleton_method(:token_class) { OperatorToken }
    harness
  end
end
