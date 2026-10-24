# typed: false
# frozen_string_literal: true

require "test_helper"

# WU-07 A07-0: every catalogued reason belongs to exactly one D-73 class, and the rendered classes
# answer with one status each.
class SignInPathRefusalValueTest < ActiveSupport::TestCase
  test "each reason maps to one of the six classes" do
    SignInPathRefusalValue::REASONS.each do |reason, refusal_class|
      assert_includes SignInPathRefusalValue::CLASSES, refusal_class, reason
      assert_equal refusal_class, SignInPathRefusalValue.for(reason).refusal_class
    end
  end

  test "ownership mismatch and definitive refusals share the uniform status" do
    assert_equal :bad_request, SignInPathRefusalValue.for("ownership_mismatch").status
    assert_equal :bad_request, SignInPathRefusalValue.for("curfew_passed").status
    assert_equal :service_unavailable, SignInPathRefusalValue.for("store_unavailable").status
    assert_equal :internal_server_error, SignInPathRefusalValue.for("invariant_broken").status
  end

  test "retryable and protocol refusals are not rendered by the responder" do
    %w(turnstile_failed oidc_access_denied).each do |reason|
      assert_raises(ArgumentError) { SignInPathRefusalValue.for(reason).status }
    end
  end

  test "an unknown reason is refused" do
    assert_raises(ArgumentError) { SignInPathRefusalValue.for("anything_else") }
  end
end
