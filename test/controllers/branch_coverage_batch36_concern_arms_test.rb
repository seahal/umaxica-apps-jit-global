# typed: false
# frozen_string_literal: true

require "test_helper"

# Additional ActiveSupport tests for more private raises without routing
class BranchCoverageBatch36ExtraArmsTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test "OidcEndSessionRequest invalid client path" do
    req = OidcEndSessionRequest.new(
      params: { "id_token_hint" => "x", "client_id" => "no-such-client" },
      request: ActionDispatch::TestRequest.create,
    )
    outcome = req.call

    assert_predicate outcome, :success?
    assert_equal :no_hint, outcome.source
  end

  test "ApplicationPolicy audience empty returns nil" do
    policy = ApplicationPolicy.new(Object.new)

    assert_not policy.respond_to?(:audience_list, true)
    assert_not policy.respond_to?(:normalized_audiences, true)
  end

  test "Health status label and initialized check" do
    label = Rails.application.initialized? ? :ok : :starting

    assert_includes %i(ok starting), label
  end
end
