# typed: false
# frozen_string_literal: true

require "test_helper"

class BranchCoverageBatch16ZerosAndPrecisionTest < ActiveSupport::TestCase
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
end
