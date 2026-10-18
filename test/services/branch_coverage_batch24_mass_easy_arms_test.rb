# typed: false
# frozen_string_literal: true

require "test_helper"

# Mass unit tops for still-cold raise/return arms that do not need the request stack.
class BranchCoverageBatch24MassEasyArmsTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test "Withdrawable recovery and early-termination blank arms" do
    client = Client.new
    client.define_singleton_method(:deactivated_at) { nil }
    client.define_singleton_method(:recovery_deadline) { 1.day.from_now }
    client.define_singleton_method(:recovery_available_at) { nil }
    client.define_singleton_method(:suspended?) { true }
    client.define_singleton_method(:early_termination_available_at) { nil }

    assert_predicate client, :can_recover?
    assert_nil Client.new.recovery_available_at
    assert_nil Client.new.early_termination_available_at
    assert_not client.early_terminatable?
  end

  test "SignUpStepGate refuses mismatched family unusable tickets and unknown steps" do
    controller = ApplicationController.new
    request = ActionDispatch::TestRequest.create
    request.set_header("rack.session", ActionController::TestSession.new)
    controller.set_request!(request)
    controller.set_response!(ActionDispatch::TestResponse.new)
    now = ClientSignUpFlow.database_now
    flow = ClientSignUpFlow.create!(
      entry_method: "telephone", step: "start", issued_at: now - 15.minutes, expires_at: now + 15.minutes,
      nonce_digest: ClientSignUpFlow.digest_nonce("gate-family"),
    )
    SignUpCycleLocator.new(controller.session, surface: :app).issue!(flow)
    controller.params = ActionController::Parameters.new(
      AuthIoKeys::Params::FLOW_BINDING => SignFlowBindingCodec.encode(flow: flow, surface: :app),
    )
    mismatch = SignUpStepGate.for_show(controller: controller, surface: :app, family: "email", step: :otp)

    assert_equal :invalid, mismatch.status
    assert_equal ["family does not match ticket"], mismatch.errors
    wrong_phase = SignUpStepGate.for_show(controller: controller, surface: :app, family: "telephone", step: :otp)

    assert_equal :refused, wrong_phase.status
    assert_equal :phase, wrong_phase.refusal
    assert_equal "start", flow.reload.step
    # Place the existing flow on the expired side without waiting out its TTL.
    flow.update_columns(expires_at: ClientSignUpFlow.database_now - 1.second)
    flow.expire_sign_up!
    expired = SignUpStepGate.for_show(controller: controller, surface: :app, family: "telephone", step: :otp)

    assert_equal :refused, expired.status
    assert_equal :no_active_flow, expired.refusal
  end

  test "AuthenticationBulletinGate treats blank bulletin state as expired" do
    helper = Class.new(ApplicationController) do
      include AuthenticationBulletinGate
      include AuthenticationBase
    end.new
    helper.set_request!(ActionDispatch::TestRequest.create)
    helper.set_response!(ActionDispatch::TestResponse.new)
    helper.define_singleton_method(:session) { @__session ||= {} }

    assert_predicate helper, :bulletin_expired?
    assert_nil helper.send(:refresh_bulletin_dimension!)
    assert_nil helper.current_bulletin
  end

  test "RedirectsExternalTargetResolver refuses blank origins" do
    resolver = RedirectsExternalTargetResolver.new(:rp_app, path: "/", query: {}, source: :explicit_external)
    resolver.define_singleton_method(:origin_for) { |_| "" }

    assert_equal "invalid_origin", resolver.call.failure_reason
  end
end
