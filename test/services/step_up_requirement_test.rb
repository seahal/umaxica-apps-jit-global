# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class StepUpRequirementTest < ActiveSupport::TestCase
  test "build rejects a legacy AAL demand instead of translating it" do
    assert_raises(ArgumentError) do
      StepUpRequirement.build({ scope: "profile", required_aal: "aal2" }, purpose: "step_up")
    end
  end

  test "build requires the complete explicit contract" do
    assert_raises(ArgumentError) do
      StepUpRequirement.build(nil, scope: "profile")
    end
  end

  test "normal step up keeps freshness separate from assurance" do
    requirement = StepUpRequirement.new(
      step_up_required: true,
      scope: "profile",
      required_aal: nil,
      phishing_resistant_required: false,
      user_verification_required: false,
      full_reauthentication_required: false,
      allowed_methods: %i(passkey totp email_otp),
      ttl: 15.minutes,
      purpose: "step_up",
      audience: "step_up:app",
      session_binding: "session-1",
      token_binding: "token-1",
      require_session_binding: true,
      actor_ref: "actor-1",
      resource_ref: nil,
      tenant_ref: nil,
    )

    assert_predicate requirement, :step_up_required?
    assert_nil requirement.required_aal
    assert_not_predicate requirement, :aal_required?
    assert_not_predicate requirement, :phishing_resistant_required?
    assert requirement.method_allowed?(:email_otp)
  end

  test "high assurance conditions remain independently expressible" do
    requirement = StepUpRequirement.new(
      step_up_required: true,
      scope: "profile",
      phishing_resistant_required: true,
      user_verification_required: true,
      full_reauthentication_required: false,
      allowed_methods: [:passkey],
      ttl: 15.minutes,
      purpose: "step_up",
      audience: "step_up:app",
      session_binding: "session-1",
      token_binding: "token-1",
      require_session_binding: true,
      actor_ref: "actor-1",
      resource_ref: nil,
      tenant_ref: nil,
    )

    assert_predicate requirement, :phishing_resistant_required?
    assert_predicate requirement, :user_verification_required?
    assert_not_predicate requirement, :full_reauthentication_required?
    assert_equal "actor-1", requirement.actor_ref
    assert_nil requirement.resource_ref
    assert_nil requirement.tenant_ref
  end

  test "required requirements reject omitted mandatory booleans and bindings" do
    assert_raises(ArgumentError) do
      StepUpRequirement.new(
        scope: "profile", allowed_methods: [:passkey], ttl: 15.minutes,
        purpose: "step_up", audience: "step_up:app", session_binding: "session-1",
        token_binding: "token-1", require_session_binding: true, actor_ref: "actor-1",
        resource_ref: nil, tenant_ref: nil,
      )
    end

    assert_raises(ArgumentError) do
      StepUpRequirement.new(
        scope: "profile", phishing_resistant_required: false,
        user_verification_required: false, full_reauthentication_required: false,
        allowed_methods: [:passkey], ttl: 15.minutes, purpose: "step_up",
        audience: "step_up:app", session_binding: "session-1", token_binding: "token-1",
        require_session_binding: true, actor_ref: nil, resource_ref: nil, tenant_ref: nil,
      )
    end
  end

  test "boolean values are strict and unsupported legacy AAL demands are refused" do
    assert_raises(ArgumentError) do
      StepUpRequirement.new(
        step_up_required: "false", phishing_resistant_required: false,
        user_verification_required: false, full_reauthentication_required: false,
        allowed_methods: [], ttl: 15.minutes, scope: nil, purpose: nil, audience: nil,
        session_binding: nil, token_binding: nil, require_session_binding: false,
        actor_ref: nil, resource_ref: nil, tenant_ref: nil,
      )
    end

    assert_raises(ArgumentError) do
      StepUpRequirement.new(
        required_aal: :aal2, scope: "profile", phishing_resistant_required: false,
        user_verification_required: false, full_reauthentication_required: false,
        allowed_methods: [:passkey], ttl: 15.minutes, purpose: "step_up",
        audience: "step_up:app", session_binding: "session-1", token_binding: "token-1",
        require_session_binding: true, actor_ref: "actor-1", resource_ref: nil, tenant_ref: nil,
      )
    end
  end

  test "disabled requirements cannot carry step-up-only properties" do
    requirement = StepUpRequirement.new(
      step_up_required: false, phishing_resistant_required: false,
      user_verification_required: false, full_reauthentication_required: false,
      allowed_methods: [], ttl: nil, scope: nil, purpose: nil, audience: nil,
      session_binding: nil, token_binding: nil, require_session_binding: false,
      actor_ref: nil, resource_ref: nil, tenant_ref: nil,
    )

    assert_not_predicate requirement, :step_up_required?

    assert_raises(ArgumentError) do
      StepUpRequirement.new(
        step_up_required: false, phishing_resistant_required: true,
        user_verification_required: false, full_reauthentication_required: false,
        allowed_methods: [:passkey], ttl: 15.minutes, scope: "profile",
        purpose: "step_up", audience: "step_up:app", session_binding: "session-1",
        token_binding: "token-1", require_session_binding: true, actor_ref: "actor-1",
        resource_ref: nil, tenant_ref: nil,
      )
    end
  end
end
