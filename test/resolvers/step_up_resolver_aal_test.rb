# typed: false
# frozen_string_literal: true

require "test_helper"

# When a scope demands a particular authenticator assurance level, a step-up
# recorded at a different level must not satisfy it, and a session that carries
# no recorded level at all must not satisfy it either -- otherwise a password
# re-entry would clear a scope that asks for a phishing-resistant factor.
class StepUpResolverAalTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  def token_with(aal:, at: Time.current, scope: "settings_email", method: "passkey")
    token = Struct.new(
      :last_step_up_aal, :last_step_up_at, :last_step_up_scope, :last_step_up_method,
      :public_id, :id, keyword_init: true,
    )
      .new(
        last_step_up_aal: aal,
        last_step_up_at: at,
        last_step_up_scope: scope,
        last_step_up_method: method,
        public_id: "token-public-id",
        id: 1,
      )
    token.define_singleton_method(:currently_usable?) { |_now = Time.current| true }
    token
  end

  test "the demanded level is carried onto the resolved step-up state" do
    result = StepUpResolver.call(token: token_with(aal: "aal2"), scope: "settings_email", required_aal: :aal2)

    assert_equal :aal2, result.required_aal
    assert_equal "settings_email", result.scope
  end

  test "a step-up recorded at a different level does not satisfy the requirement" do
    result = StepUpResolver.call(token: token_with(aal: "aal1"), scope: "settings_email", required_aal: :aal2)

    assert_not result.satisfied
  end

  test "a session carrying no recorded level does not satisfy a requirement that demands one" do
    result = StepUpResolver.call(token: token_with(aal: nil), scope: "settings_email", required_aal: :aal2)

    assert_not result.satisfied
  end

  test "a requirement that demands no particular level records none" do
    result = StepUpResolver.call(token: token_with(aal: nil), scope: "settings_email")

    assert_nil result.required_aal
  end
end
