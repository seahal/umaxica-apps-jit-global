# typed: false
# frozen_string_literal: true

require "test_helper"

# A second group of narrow seams shared across surfaces. Each is a decision the
# surrounding controller delegates: which template answers a suspended sign-up,
# where the ceremony reference lives between the start and the callback, and
# what a signed redirect target resolves to when it cannot be trusted.
class SharedSeamFallbacksTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test "a resolver result with no resource is not a success" do
    result = AuthenticationCurrentResourceResolver::Result.new(resource: nil)

    assert_not result.success?
    assert_predicate AuthenticationCurrentResourceResolver::Result.new(resource: Object.new), :success?
  end
end
