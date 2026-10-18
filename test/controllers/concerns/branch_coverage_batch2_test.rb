# typed: false
# frozen_string_literal: true

require "test_helper"

class BranchCoverageBatch2Test < ActiveSupport::TestCase
  test "TokenStatusManagement currently_usable discarded and scheduled revocation" do
    token = ClientToken.new
    if token.has_attribute?(:discard_at)
      token.discard_at = 1.minute.ago

      assert_not token.currently_usable?
    end

    token2 = ClientToken.new(user_token_status_id: ClientTokenStatus::ACTIVE)
    token2.define_singleton_method(:scheduled_revocation_due?) { |*_args| true }

    assert_predicate token2, :expired?
  end

  test "Avatar current binding nil for unpersisted records" do
    avatar = Avatar.new

    assert_nil avatar.current_avatar_persona_binding
  end
end
