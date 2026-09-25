# typed: false
# frozen_string_literal: true

require "test_helper"
require_relative "../support/avatar_test_factory"

class GroupAvatarMembershipsTest < ActiveSupport::TestCase
  test "attaches an active Avatar to an active group with the same current owner" do
    context = app_context
    membership = GroupAvatarMemberships::Attach.call(**attach_arguments(context))

    assert_predicate membership, :persisted?
    assert_equal "active", membership.state
    assert_equal GroupAvatarMembership::ROLE, membership.role
    assert_equal context.fetch(:avatar).id, membership.avatar_id
  end

  test "attach rejects an Avatar whose current owner differs from the Group owner" do
    context = app_context
    other_actor = Client.create!(status_id: ClientStatus::ACTIVE, visibility_id: ClientVisibility::USER)
    other_avatar = BaseSelectorBootstrapAuthority.call(surface: :app, principal: other_actor).avatar

    assert_no_difference -> { GroupAvatarMembership.count } do
      error =
        assert_raises(ArgumentError) do
          GroupAvatarMemberships::Attach.call(**attach_arguments(context).merge(avatar: other_avatar))
        end

      assert_equal "group and Avatar current owners differ", error.message
    end
  end

  test "member membership cannot attach even when both current owners match" do
    context = app_context
    context.fetch(:bootstrap).account.persona_memberships
      .find_by!(enterprise: context.fetch(:bootstrap).collective)
      .update!(membership_kind_id: PersonaMembershipKind::MEMBER)

    assert_no_difference -> { GroupAvatarMembership.count } do
      error =
        assert_raises(GroupAvatarMemberships::Attach::AuthorizationDenied) do
          GroupAvatarMemberships::Attach.call(**attach_arguments(context))
        end
      assert_equal "avatar.group.attach permission required", error.message
    end
  end

  test "database rejects group membership roles other than member" do
    context = app_context
    now = Time.current

    assert_raises(ActiveRecord::StatementInvalid) do
      GroupAvatarMembership.insert!(
        {
          public_id: "group-role-#{SecureRandom.hex(4)}",
          avatar_group_id: context.fetch(:group).id,
          avatar_id: context.fetch(:avatar).id,
          role: "owner",
          position: 0,
          state: "active",
          assigned_at: now,
          created_at: now,
          updated_at: now,
        },
      )
    end
  end

  test "does not attach an Avatar to an archived group" do
    context = app_context
    context.fetch(:group).update!(state: "archived", archived_at: Time.current)

    error =
      assert_raises(ArgumentError) do
        GroupAvatarMemberships::Attach.call(**attach_arguments(context))
      end

    assert_equal "group is not active", error.message
  end

  test "detach marks an active membership removed" do
    context = app_context
    membership = GroupAvatarMemberships::Attach.call(**attach_arguments(context))

    GroupAvatarMemberships::Detach.call(**authorization_arguments(context).merge(membership: membership))

    assert_equal "removed", membership.reload.state
    assert_predicate membership.removed_at, :present?
  end

  test "a current group owner can detach a stale membership after Avatar ownership changes" do
    context = app_context
    membership = GroupAvatarMemberships::Attach.call(**attach_arguments(context))
    source_period = context.fetch(:avatar).current_ownership_period
    source_period.update!(valid_to: Time.current)
    AvatarOwnershipPeriod.create!(
      avatar: context.fetch(:avatar),
      owner_organization_id: "transitional-owner",
      owner_surface: "org",
      owner_collective_public_id: "bureau-public-id",
      avatar_ownership_status_id: AvatarOwnershipStatus::ACTIVE,
      valid_from: Time.current,
    )

    GroupAvatarMemberships::Detach.call(**authorization_arguments(context).merge(membership: membership))

    assert_equal "removed", membership.reload.state
  end

  test "reorders an active membership and rejects negative positions" do
    context = app_context
    membership = GroupAvatarMemberships::Attach.call(**attach_arguments(context))
    arguments = authorization_arguments(context).merge(membership: membership)

    result = GroupAvatarMemberships::Reorder.call(**arguments, position: 3)

    assert_equal membership.id, result.id
    assert_equal 3, membership.reload.position

    error =
      assert_raises(ArgumentError) do
        GroupAvatarMemberships::Reorder.call(**arguments, position: -1)
      end
    assert_equal "position must be non-negative", error.message
    assert_equal 3, membership.reload.position
  end

  private

  def app_context
    actor = Client.create!(status_id: ClientStatus::ACTIVE, visibility_id: ClientVisibility::USER)
    bootstrap = BaseSelectorBootstrapAuthority.call(surface: :app, principal: actor)
    group = AvatarGroup.create!(
      account_surface: "app",
      account_public_id: bootstrap.account.public_id,
      name: "Authorized Group",
      state: "active",
    )
    AvatarGroupOwnershipPeriod.create!(
      avatar_group: group,
      owner_surface: "app",
      owner_collective_public_id: bootstrap.collective.public_id,
      valid_from: Time.current,
    )

    {
      group: group,
      avatar: bootstrap.avatar,
      actor: actor,
      surface: "app",
      subject_public_id: bootstrap.account.public_id,
      account_public_id: bootstrap.account.public_id,
      bootstrap: bootstrap,
    }
  end

  def authorization_arguments(context)
    context.slice(:actor, :surface, :subject_public_id, :account_public_id)
  end

  def attach_arguments(context)
    context.except(:bootstrap)
  end
end
