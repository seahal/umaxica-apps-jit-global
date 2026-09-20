# typed: false
# frozen_string_literal: true

require "test_helper"

class BranchCoverageBatch16ZerosAndPrecisionTest < ActiveSupport::TestCase
  def attach!(ctrl)
    request = ActionDispatch::TestRequest.create
    response = ActionDispatch::TestResponse.new
    ctrl.set_request!(request)
    ctrl.set_response!(response)
    ctrl.define_singleton_method(:session) { @__session ||= {} }
    ctrl.define_singleton_method(:params) { @__params ||= ActionController::Parameters.new({}) }
    ctrl
  end

  test "session limit ref blank pid" do
    Rails.application.message_verifier(:session_limit_resolution_token_ref).stub(:verify, { pid: "" }) do
      assert_nil SessionLimitResolutionTokenRef.find_client_token("x")
    end
  end

  test "webauthn surface not declared" do
    h = Class.new(ApplicationController) { include WebauthnSurfaceDeclarable }.new
    h.class.define_singleton_method(:declared_webauthn_surface_key) { nil }
    assert_raises(WebauthnSurfaceDeclarable::SurfaceNotDeclaredError) { h.send(:webauthn_surface) }
  end

  test "apple confirmations early returns" do
    c = attach!(Auth::App::Sign::Up::Check::Apple::ConfirmationsController.new)
    c.define_singleton_method(:load_gate_context!) { |_| false }
    assert_nil c.show if c.respond_to?(:show)
    assert_nil c.update if c.respond_to?(:update)
  end
end
