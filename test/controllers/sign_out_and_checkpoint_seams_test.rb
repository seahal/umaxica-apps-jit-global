# typed: false
# frozen_string_literal: true

require "test_helper"

# Small per-surface overrides around sign-out and the sign-in checkpoint. The
# base surfaces render their own document layout when a logout challenge is
# rejected, the confirmation form posts back to the surface's own endpoint, and
# the checkpoint page starts from an empty item list rather than a nil one.
class SignOutAndCheckpointSeamsTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  [
    SignAppInCheckControllerSupport,
    SignComInCheckControllerSupport,
    SignOrgInCheckControllerSupport,
  ].each do |concern|
    test "#{concern.name} starts the checkpoint page from an empty item list" do
      harness = Class.new { include concern }.new

      harness.show

      assert_empty harness.instance_variable_get(:@checkpoint_items)
    end
  end
end
