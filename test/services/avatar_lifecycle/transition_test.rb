# typed: false
# frozen_string_literal: true

require "test_helper"
require_relative "../../support/avatar_test_factory"

class AvatarLifecycleTransitionTest < ActiveSupport::TestCase
  setup do
    @capability = avatar_capabilities(:normal)
  end

  test "active to suspended succeeds and creates an event" do
    handle = Handle.create!(handle: "lifecycle-suspend-#{SecureRandom.hex(4)}", cooldown_until: Time.current)
    avatar = AvatarTestFactory.create!(
      capability: @capability,
      active_handle: handle,
      lifecycle_state: avatar_lifecycle_states(:active),
      moniker: "Suspend",
    )

    assert_difference "AvatarLifecycleEvent.count", 1 do
      AvatarLifecycle::Transition.call(
        avatar: avatar,
        to_state_key: "suspended",
        changed_by_type: "moderator",
        changed_by_public_id: "moderator-1",
        reason: "moderation hold",
      )
    end

    assert_equal "suspended", avatar.reload.lifecycle_state.key
    event = avatar.avatar_lifecycle_events.order(:created_at).last

    assert_equal "active", event.from_state_key
    assert_equal "suspended", event.to_state_key
  end

  test "suspended to active succeeds" do
    handle = Handle.create!(handle: "lifecycle-unsuspend-#{SecureRandom.hex(4)}", cooldown_until: Time.current)
    avatar = AvatarTestFactory.create!(
      capability: @capability,
      active_handle: handle,
      lifecycle_state: avatar_lifecycle_states(:suspended),
      moniker: "Unsuspend",
    )

    AvatarLifecycle::Transition.call(
      avatar: avatar,
      to_state_key: "active",
      changed_by_type: "moderator",
      changed_by_public_id: "moderator-1",
      reason: "review complete",
    )

    assert_equal "active", avatar.reload.lifecycle_state.key
  end

  test "active to archived succeeds" do
    handle = Handle.create!(handle: "lifecycle-archive-#{SecureRandom.hex(4)}", cooldown_until: Time.current)
    avatar = AvatarTestFactory.create!(
      capability: @capability,
      active_handle: handle,
      lifecycle_state: avatar_lifecycle_states(:active),
      moniker: "Archive",
    )

    AvatarLifecycle::Transition.call(
      avatar: avatar,
      to_state_key: "archived",
      changed_by_type: "owner",
      changed_by_public_id: "owner-1",
      reason: "owner archive",
    )

    assert_equal "archived", avatar.reload.lifecycle_state.key
  end

  test "archived to active succeeds" do
    handle = Handle.create!(handle: "lifecycle-restore-#{SecureRandom.hex(4)}", cooldown_until: Time.current)
    avatar = AvatarTestFactory.create!(
      capability: @capability,
      active_handle: handle,
      lifecycle_state: avatar_lifecycle_states(:archived),
      moniker: "Restore",
    )

    AvatarLifecycle::Transition.call(
      avatar: avatar,
      to_state_key: "active",
      changed_by_type: "owner",
      changed_by_public_id: "owner-1",
      reason: "owner restore",
    )

    assert_equal "active", avatar.reload.lifecycle_state.key
  end

  test "active to banned succeeds" do
    handle = Handle.create!(handle: "lifecycle-ban-#{SecureRandom.hex(4)}", cooldown_until: Time.current)
    avatar = AvatarTestFactory.create!(
      capability: @capability,
      active_handle: handle,
      lifecycle_state: avatar_lifecycle_states(:active),
      moniker: "Ban",
    )

    AvatarLifecycle::Transition.call(
      avatar: avatar,
      to_state_key: "banned",
      changed_by_type: "admin",
      changed_by_public_id: "admin-1",
      reason: "abuse decision",
    )

    assert_equal "banned", avatar.reload.lifecycle_state.key
  end

  test "banned to deleted succeeds" do
    handle = Handle.create!(handle: "lifecycle-delete-ban-#{SecureRandom.hex(4)}", cooldown_until: Time.current)
    avatar = AvatarTestFactory.create!(
      capability: @capability,
      active_handle: handle,
      lifecycle_state: avatar_lifecycle_states(:banned),
      moniker: "Delete Ban",
    )

    AvatarLifecycle::Transition.call(
      avatar: avatar,
      to_state_key: "deleted",
      changed_by_type: "admin",
      changed_by_public_id: "admin-1",
      reason: "retention minimum",
    )

    assert_equal "deleted", avatar.reload.lifecycle_state.key
  end

  test "deleted to active fails without creating an event" do
    handle = Handle.create!(handle: "lifecycle-deleted-#{SecureRandom.hex(4)}", cooldown_until: Time.current)
    avatar = AvatarTestFactory.create!(
      capability: @capability,
      active_handle: handle,
      lifecycle_state: avatar_lifecycle_states(:deleted),
      moniker: "Deleted",
    )

    assert_no_difference "AvatarLifecycleEvent.count" do
      assert_raises(AvatarLifecycle::InvalidTransition) do
        AvatarLifecycle::Transition.call(
          avatar: avatar,
          to_state_key: "active",
          changed_by_type: "admin",
          changed_by_public_id: "admin-1",
          reason: "not allowed",
        )
      end
    end
  end

  test "owner cannot restore banned to active and no event is created" do
    handle = Handle.create!(handle: "lifecycle-owner-ban-#{SecureRandom.hex(4)}", cooldown_until: Time.current)
    avatar = AvatarTestFactory.create!(
      capability: @capability,
      active_handle: handle,
      lifecycle_state: avatar_lifecycle_states(:banned),
      moniker: "Owner Ban",
    )

    assert_no_difference "AvatarLifecycleEvent.count" do
      assert_raises(AvatarLifecycle::InvalidTransition) do
        AvatarLifecycle::Transition.call(
          avatar: avatar,
          to_state_key: "active",
          changed_by_type: "owner",
          changed_by_public_id: "owner-1",
          reason: "owner restore",
        )
      end
    end
  end

  test "active to suspended by owner fails without creating an event" do
    handle = Handle.create!(handle: "lifecycle-bad-actor-#{SecureRandom.hex(4)}", cooldown_until: Time.current)
    avatar = AvatarTestFactory.create!(
      capability: @capability,
      active_handle: handle,
      lifecycle_state: avatar_lifecycle_states(:active),
      moniker: "Bad Actor",
    )

    assert_no_difference "AvatarLifecycleEvent.count" do
      assert_raises(AvatarLifecycle::UnauthorizedTransition) do
        AvatarLifecycle::Transition.call(
          avatar: avatar,
          to_state_key: "suspended",
          changed_by_type: "owner",
          changed_by_public_id: "owner-1",
          reason: "not authorized",
        )
      end
    end
  end
end
