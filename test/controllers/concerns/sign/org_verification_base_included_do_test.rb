# typed: false
# frozen_string_literal: true

require "test_helper"

# Retained legacy VerificationOperator coverage; this harness does not establish ceremony admission.
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
