# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class SignUp::ParticipantPolicyTest < ActiveSupport::TestCase
  test "enter_guardrail? is true but enter_checkpoint? is false at contact_verified" do
    policy = build_policy(step: "contact_verified", status: :contact_verified)

    assert policy.send(:enter_guardrail?)
    assert_not policy.send(:enter_checkpoint?)
  end

  test "enter_checkpoint? is true for a mutable ticket at guardrail or checkpoint" do
    guardrail_policy = build_policy(step: "guardrail", status: :guardrail_pending)

    assert guardrail_policy.send(:enter_checkpoint?)
    assert_not guardrail_policy.send(:enter_guardrail?)

    checkpoint_policy = build_policy(step: "checkpoint", status: :checkpoint_pending)

    assert checkpoint_policy.send(:enter_checkpoint?)
    assert_not checkpoint_policy.send(:enter_guardrail?)
  end

  test "both actions are false for an immutable ticket" do
    policy = build_policy(step: "start", status: :started)

    assert_not policy.send(:enter_guardrail?)
    assert_not policy.send(:enter_checkpoint?)
  end

  private

  def build_policy(step:, status:)
    ClientSignUpFlowStatus.ensure_defaults!

    status_id = ClientSignUpFlowStatus.const_get(status.to_s.upcase)
    flow = ClientSignUpFlow.new(
      status_id: status_id,
      step: step.to_s,
      public_id: "seq123",
      entry_method: "email",
      completed_requirements: {},
    )
    auth = Struct.new(:signed_in?, :active_sign_sequence_id).new(false, "seq123")
    flow.define_singleton_method(:actor_authentication) { auth }

    SignUp::ParticipantPolicy.new(flow, user: nil)
  end
end
