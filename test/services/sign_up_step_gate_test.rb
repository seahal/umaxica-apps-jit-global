# typed: false
# frozen_string_literal: true

require "test_helper"

class SignUpStepGateTest < ActiveSupport::TestCase
  setup do
    ClientSignUpFlowStatus::DEFAULTS.each { |id| ClientSignUpFlowStatus.find_or_create_by!(id: id) }
    ClientSignUpFlowCleanupStatus::DEFAULTS.each { |id| ClientSignUpFlowCleanupStatus.find_or_create_by!(id: id) }
  end

  ControllerBoundary = Struct.new(:session, :params, :current_sign_up_flow_ticket, :sign_up_ticket_public_id)

  test "for_show falls back to the session sequence id with its signed flow binding" do
    ClientSignUpFlowStatus.ensure_defaults!
    cycle = ClientSignUpFlow.create!(
      entry_method: "google", step: "checkpoint",
      status_id: ClientSignUpFlowStatus::CHECKPOINT_PENDING,
      nonce_digest: ClientSignUpFlow.digest_nonce("gate-sequence"),
      completed_requirements: {},
    )
    controller = ControllerBoundary.new(
      { auth_app_up_sequence_id: cycle.public_id },
      { AuthIoKeys::Params::FLOW_BINDING => SignFlowBindingCodec.encode(flow: cycle, surface: :app) },
      nil, cycle.public_id,
    )

    gate = SignUpStepGate.for_show(controller: controller, surface: :app, family: "google", step: :confirmation)

    assert_predicate gate, :success?
    assert_equal cycle, gate.ticket
    assert_equal :ok, gate.status
    binding = SignFlowBindingCodec.decode(controller.params.fetch(AuthIoKeys::Params::FLOW_BINDING))
    assert_equal cycle.step, binding.phase
    assert_equal cycle.checkpoint_version, binding.generation
    assert_equal cycle.expires_at.to_i, binding.expires_at
  end

  test "for_show prefers the controller ticket with its signed flow binding when the locator is empty" do
    cycle = ClientSignUpFlow.new(
      public_id: "controller-gate-flow", entry_method: "google", step: "checkpoint",
      status_id: ClientSignUpFlowStatus::CHECKPOINT_PENDING,
      completed_requirements: {}, expires_at: 15.minutes.from_now,
    )
    controller = ControllerBoundary.new(
      {}, { AuthIoKeys::Params::FLOW_BINDING => SignFlowBindingCodec.encode(flow: cycle, surface: :app) },
      cycle, nil,
    )

    gate = SignUpStepGate.for_show(controller: controller, surface: :app, family: "google", step: :confirmation)

    assert_predicate gate, :success?
    assert_equal cycle, gate.ticket
  end

  test "for_show refuses when neither locator nor sequence id is present" do
    controller = ControllerBoundary.new({}, {}, nil, nil)

    gate = SignUpStepGate.for_show(controller: controller, surface: :app, family: "google", step: :confirmation)

    assert_equal :refused, gate.status
    assert_equal :no_active_flow, gate.refusal
    assert_equal ["request contradicts the authoritative sign-up flow"], gate.errors
  end

  test "for_show refuses an existing flow without its signed binding" do
    cycle = ClientSignUpFlow.new(
      public_id: "unbound-gate-flow", entry_method: "google", step: "checkpoint",
      status_id: ClientSignUpFlowStatus::CHECKPOINT_PENDING, completed_requirements: {},
    )
    controller = ControllerBoundary.new({}, {}, cycle, nil)

    gate = SignUpStepGate.for_show(controller: controller, surface: :app, family: "google", step: :confirmation)

    assert_equal :refused, gate.status
    assert_equal :flow_binding, gate.refusal
    assert_nil gate.ticket
  end

  test "for_show refuses a signed binding from an earlier checkpoint generation" do
    cycle = ClientSignUpFlow.create!(
      entry_method: "email", step: "checkpoint",
      status_id: ClientSignUpFlowStatus::CHECKPOINT_PENDING,
      nonce_digest: ClientSignUpFlow.digest_nonce("stale-checkpoint-binding"),
      completed_requirements: {},
    )
    binding = SignFlowBindingCodec.encode(flow: cycle, surface: :app)
    cycle.update!(checkpoint_version: cycle.checkpoint_version + 1)
    controller = ControllerBoundary.new(
      { auth_app_up_sequence_id: cycle.public_id },
      { AuthIoKeys::Params::FLOW_BINDING => binding },
      nil, cycle.public_id,
    )

    gate = SignUpStepGate.for_show(controller: controller, surface: :app, family: "email", step: :otp)

    assert_equal :refused, gate.status
    assert_equal :phase, gate.refusal
  end
end
