# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: handle_assignments
# Database name: avatar
#
#  id                          :bigint           not null, primary key
#  valid_from                  :datetime         not null
#  valid_to                    :datetime         default(Infinity), not null
#  created_at                  :datetime         not null
#  updated_at                  :datetime         not null
#  assigned_by_actor_id        :bigint
#  avatar_id                   :bigint           not null
#  handle_assignment_status_id :bigint
#  handle_id                   :bigint           not null
#
# Indexes
#
#  index_handle_assignments_on_assigned_by_actor_id         (assigned_by_actor_id)
#  index_handle_assignments_on_avatar_id                    (avatar_id) UNIQUE WHERE (valid_to = 'infinity'::timestamp with time zone)
#  index_handle_assignments_on_avatar_id_and_valid_from     (avatar_id,valid_from DESC)
#  index_handle_assignments_on_handle_assignment_status_id  (handle_assignment_status_id)
#  index_handle_assignments_on_handle_id                    (handle_id) UNIQUE WHERE (valid_to = 'infinity'::timestamp with time zone)
#  index_handle_assignments_on_handle_id_and_valid_from     (handle_id,valid_from DESC)
#
# Foreign Keys
#
#  fk_rails_...  (avatar_id => avatars.id)
#  fk_rails_...  (handle_assignment_status_id => handle_assignment_statuses.id)
#  fk_rails_...  (handle_id => handles.id)
#

require "test_helper"
require_relative "../support/avatar_test_factory"

class HandleAssignmentTest < ActiveSupport::TestCase
  setup do
    unique_suffix = SecureRandom.hex(4)
    @capability = AvatarCapability.find_or_create_by!(id: AvatarCapability::NORMAL)
    @system_handle = Handle.create!(
      handle: "__unassigned__#{unique_suffix}",
      is_system: true,
      cooldown_until: 1.week.from_now,
    )
    @avatar = AvatarTestFactory.create!(
      moniker: "Avatar",
      capability: @capability,
      active_handle: @system_handle,
    )
  end

  test "current_attributes returns handle and avatar ids" do
    assert_equal [:handle_id, :avatar_id], HandleAssignment.current_attributes
  end

  test "valid_to defaults to infinity" do
    assignment = HandleAssignment.create!(
      avatar: @avatar,
      handle: @system_handle,
      valid_from: Time.current,
    )

    valid_to = assignment.reload.valid_to

    assert_predicate valid_to, :present?
    assert valid_to.to_s == "infinity" || (valid_to.is_a?(Float) && valid_to == Float::INFINITY)
  end

  test "prevents multiple active assignments for the same handle" do
    HandleAssignment.create!(
      avatar: @avatar,
      handle: @system_handle,
      valid_from: Time.current,
    )

    other_handle = Handle.create!(handle: "other-#{SecureRandom.hex(4)}", cooldown_until: 1.week.from_now)
    other_avatar = AvatarTestFactory.create!(
      moniker: "Another",
      capability: @capability,
      active_handle: other_handle,
    )

    assert_raises ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique do
      HandleAssignment.create!(
        avatar: other_avatar,
        handle: @system_handle,
        valid_from: Time.current,
      )
    end
  end
end
