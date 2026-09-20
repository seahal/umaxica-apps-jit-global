# typed: false
# frozen_string_literal: true

require "test_helper"

# The step gate decides whether a sign-up step may be shown or a challenge issued
# for it. Every refusal is a step reached out of order or by a route that does not
# exist for the surface and family being asked about; letting one through would
# let a checkpoint be skipped or a challenge be issued for a step that never
# issues one.
class SignUpStepGateRefusalsTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  class ControllerDouble
    attr_accessor :session, :params, :ticket

    def initialize
      @session = {}
      @params = ActionController::Parameters.new(ri: "jp", pt: "/settings")
    end

    def current_sign_up_flow_ticket = ticket
  end

  def gate(surface: :app, family: "email", step: :otp, mode: :show, controller: ControllerDouble.new)
    SignUpStepGate.new(controller: controller, surface: surface, family: family, step: step, mode: mode)
  end

  test "a surface, family and step combination with no route is refused" do
    assert_equal ["unsupported sign-up route"], gate(surface: :org).call.errors
    assert_equal ["unsupported sign-up route"], gate(family: "line").call.errors
    assert_equal ["unsupported sign-up route"], gate(step: :not_a_step).call.errors
  end

  test "a request with no ticket at all is refused before any registry is built" do
    assert_equal ["ticket is required"], gate.call.errors
  end

  # Only the steps that actually have a challenge may have one issued. Asking for
  # one on, say, the birthdate step means the client is following a flow that does
  # not exist.
  test "issuing a challenge for a step that has none is refused" do
    controller = ControllerDouble.new
    ClientSignUpFlowStatus.ensure_defaults!
    controller.ticket = ClientSignUpFlow.new(
      step: "checkpoint",
      entry_method: "email",
      status_id: ClientSignUpFlowStatus::CHECKPOINT_PENDING,
      issued_at: Time.current,
      expires_at: 1.hour.from_now,
    )

    context = gate(step: :birthdate, mode: :create, controller: controller).call

    assert_equal :invalid, context.status
    assert_includes context.errors, "challenge issuance is not allowed for this step"
  end
end
