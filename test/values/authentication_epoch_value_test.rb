# typed: false
# frozen_string_literal: true

require "test_helper"

# D-165 / A44-8: only a root epoch equal to the actor's is current.
class AuthenticationEpochValueTest < ActiveSupport::TestCase
  Root = Struct.new(:authentication_epoch)
  Actor = Struct.new(:authentication_epoch)

  test "equal is current; one lower and one higher are refused" do
    actor = Actor.new(3)

    assert AuthenticationEpochValue.root_current?(root_token: Root.new(3), actor:)
    assert_not AuthenticationEpochValue.root_current?(root_token: Root.new(2), actor:)
    assert_not AuthenticationEpochValue.root_current?(root_token: Root.new(4), actor:), "higher means corruption"
  end
end
