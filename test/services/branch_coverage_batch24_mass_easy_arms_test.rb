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
    controller = Object.new
    gate = SignUpStepGate.new(controller: controller, surface: :app, family: "email", step: :otp, mode: :show)
    ticket = Object.new
    ticket.define_singleton_method(:expired?) { false }
    ticket.define_singleton_method(:lapsed?) { false }
    ticket.define_singleton_method(:sign_up_terminal?) { false }
    ticket.define_singleton_method(:step) { "otp" }
    ticket.define_singleton_method(:respond_to?) do |name, include_all = false|
      return true if %i(expired? lapsed? sign_up_terminal? step).include?(name.to_sym)

      super(name, include_all)
    end
    registry = Object.new
    registry.define_singleton_method(:entry_method) { "telephone" }
    registry.define_singleton_method(:requirement?) { |_| false }

    gate.define_singleton_method(:route_known?) { true }
    gate.define_singleton_method(:current_ticket) { ticket }
    SignUpRequirementRegistry.stub(:for_ticket, registry) do
      result = gate.call

      assert_not result.success?
      assert_match(/family/, result.errors.join)
    end

    registry.define_singleton_method(:entry_method) { "email" }
    ticket.define_singleton_method(:expired?) { true }
    SignUpRequirementRegistry.stub(:for_ticket, registry) do
      result = gate.call

      assert_match(/usable|ticket/, result.errors.join)
    end

    ticket.define_singleton_method(:expired?) { false }
    ticket.define_singleton_method(:step) { "checkpoint" }
    ticket.define_singleton_method(:sign_up_checkpoint_pending?) { true }
    SignUpRequirementRegistry.stub(:for_ticket, registry) do
      result = gate.call

      assert_match(/step|belong/, result.errors.join)
    end
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
    resolver = RedirectsExternalTargetResolver.new(:jump, path: "/", query: {}, source: :explicit_external)
    resolver.define_singleton_method(:origin_for) { |_| "" }

    assert_equal "invalid_origin", resolver.call.failure_reason
  end
end
