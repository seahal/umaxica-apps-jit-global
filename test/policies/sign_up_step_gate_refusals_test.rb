# typed: false
# frozen_string_literal: true

require "test_helper"

class SignUpStepGateRefusalsTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  ControllerBoundary = Struct.new(:session, :params, :current_sign_up_flow_ticket)

  test "a surface family and step combination with no route is refused" do
    controller = ControllerBoundary.new({}, {}, nil)
    [[:org, "email", :otp], [:app, "line", :otp], [:app, "email", :not_a_step]].each do |surface, family, step|
      context = SignUpStepGate.for_show(controller: controller, surface: surface, family: family, step: step)

      assert_equal ["unsupported sign-up route"], context.errors
      assert_equal :invalid, context.status
    end
  end

  test "a request with no ticket is refused before any registry is built" do
    controller = ControllerBoundary.new({}, {}, nil)

    context = SignUpStepGate.for_show(controller: controller, surface: :app, family: "email", step: :otp)

    assert_equal :refused, context.status
    assert_equal :no_active_flow, context.refusal
    assert_equal ["request contradicts the authoritative sign-up flow"], context.errors
  end

  test "issuing a challenge for the current birthdate step is refused" do
    cycle = ClientSignUpFlow.new(
      public_id: "birthdate-challenge-flow", step: "checkpoint", entry_method: "email",
      status_id: ClientSignUpFlowStatus::CHECKPOINT_PENDING,
      completed_requirements: { "otp" => { "cleared" => true } }, expires_at: 15.minutes.from_now,
    )
    controller = ControllerBoundary.new(
      {}, { AuthIoKeys::Params::FLOW_BINDING => SignFlowBindingCodec.encode(flow: cycle, surface: :app) }, cycle,
    )

    context = SignUpStepGate.for_create(controller: controller, surface: :app, family: "email", step: :birthdate)

    assert_equal :invalid, context.status
    assert_includes context.errors, "challenge issuance is not allowed for this step"
  end
end
