# frozen_string_literal: true

require "test_helper"

class ActorValuesContextVisitorPredicateTest < ActiveSupport::TestCase
  test "visitor role predicate follows the explicit actor type" do
    visitor = ActorValuesContext.empty.with(actor_type: :visitor)
    client = ActorValuesContext.empty.with(actor_type: :client)

    assert_predicate visitor, :visitor?
    assert_not client.visitor?
  end
end
