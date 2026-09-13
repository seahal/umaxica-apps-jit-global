# typed: false
# frozen_string_literal: true

require "test_helper"

# The last group of per-surface seams: withdrawal pages, redelivery entry
# points, and the paths the shared sign-up and logout flows ask each surface
# for. As with the other two groups, each is the point where a surface could
# resolve to another surface's screen.
class SurfaceSeamPathsThirdTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  def harness_for(controller_class, params: { ri: "jp" })
    Class.new(controller_class) do
      attr_accessor :params_hash

      def params
        ActionController::Parameters.new(params_hash || {})
      end

      def invoke(name, ...) = send(name, ...)
    end.new.tap do |harness|
      harness.params_hash = params
      harness.request = ActionDispatch::TestRequest.create
    end
  end

  test "the app withdrawal page paths and payloads are built for the app surface" do
    harness = harness_for(Base::App::Identity::WithdrawalsController)
    harness.instance_variable_set(:@recovery_available, true)
    harness.instance_variable_set(:@recovery_available_at, 1.day.from_now)
    harness.instance_variable_set(:@early_terminatable, true)
    harness.instance_variable_set(:@early_termination_available_at, 1.day.from_now)

    assert_includes harness.invoke(:withdrawal_edit_path), "/identity/withdrawal"
    assert_predicate harness.invoke(:withdrawal_recovery_props), :present?
    assert_predicate harness.invoke(:withdrawal_termination_props), :present?
  end

  test "the app email redelivery returns to the app email registration entry point" do
    path = harness_for(Base::App::Identity::Emails::RedeliveriesController)
      .invoke(:new_email_registration_path)

    assert_includes path, "/identity/emails"
  end

  test "the app verification redelivery seams stay on the app verification surface" do
    harness = harness_for(Auth::App::Verification::RedeliveriesController)

    assert_predicate harness.invoke(:verification_recovery_fallback_path), :present?
    assert_predicate harness.invoke(:verification_recovery_path), :present?
  end

  test "the corporate verification redelivery names the addressed email" do
    path = harness_for(Auth::Com::Verification::RedeliveriesController, params: { ri: "jp", id: "pub-9" })
      .invoke(:verification_email_edit_path)

    assert_includes path, "pub-9"
  end

end
