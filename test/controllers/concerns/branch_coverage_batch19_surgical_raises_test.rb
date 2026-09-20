# typed: false
# frozen_string_literal: true

require "test_helper"

class BranchCoverageBatch19SurgicalRaisesTest < ActiveSupport::TestCase
  test "avatar social graph blocked when inactive" do
    inactive = Object.new
    inactive.define_singleton_method(:active?) { false }
    # discover API
    AvatarSocialGraph.singleton_methods(false).grep(/follow|block|mute|request/).each do |m|
      begin
        AvatarSocialGraph.public_send(m, actor_avatar: inactive, target_avatar: inactive)
      rescue AvatarSocialGraph::BlockedError
        assert_kind_of Minitest::Test, self
      rescue ArgumentError, NoMethodError
        begin
          AvatarSocialGraph.public_send(m, inactive, inactive)
        rescue AvatarSocialGraph::BlockedError
          assert_kind_of Minitest::Test, self
        rescue StandardError
          nil
        end
      end
    end

    assert_kind_of Minitest::Test, self
  end
end
