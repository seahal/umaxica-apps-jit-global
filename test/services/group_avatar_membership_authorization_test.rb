# typed: false
# frozen_string_literal: true

require "test_helper"

# Detaching and reordering a group membership are owner-only mutations. These cases pin the
# refusals: the wrong surface, an account scope that is not the actor's own, an actor who is not the
# current owner, and state that makes the mutation meaningless. Every refusal must leave the
# membership row untouched.
class GroupAvatarMembershipAuthorizationTest < ActiveSupport::TestCase
  setup do
    @actor = Client.create!(status_id: ClientStatus::ACTIVE, visibility_id: ClientVisibility::USER)
    @bootstrap = BaseSelectorBootstrapAuthority.call(surface: :app, principal: @actor)
    @account_public_id = @bootstrap.account.public_id
    @group = AvatarGroup.create!(
      account_surface: "app",
      account_public_id: @account_public_id,
      name: "Authorized Group",
      state: "active",
    )
    AvatarGroupOwnershipPeriod.create!(
      avatar_group: @group,
      owner_surface: "app",
      owner_collective_public_id: @bootstrap.collective.public_id,
      valid_from: Time.current,
    )
    @membership = GroupAvatarMemberships::Attach.call(
      group: @group,
      avatar: @bootstrap.avatar,
      actor: @actor,
      surface: "app",
      subject_public_id: @account_public_id,
      account_public_id: @account_public_id,
    )
  end

  test "detach is denied on a surface other than the group owner's and keeps the membership active" do
    error =
      assert_raises(GroupAvatarMemberships::Detach::AuthorizationDenied) do
        GroupAvatarMemberships::Detach.call(
          membership: @membership,
          actor: @actor,
          surface: "org",
          subject_public_id: @account_public_id,
          account_public_id: @account_public_id,
        )
      end

    assert_equal "group owner surface does not match actor surface", error.message
    assert_equal "active", @membership.reload.state
    assert_nil @membership.removed_at
  end

  test "detach is denied when the account scope is not the acting subject's own account" do
    error =
      assert_raises(GroupAvatarMemberships::Detach::AuthorizationDenied) do
        GroupAvatarMemberships::Detach.call(
          membership: @membership,
          actor: @actor,
          surface: "app",
          subject_public_id: @account_public_id,
          account_public_id: "another-account-public-id",
        )
      end

    assert_equal "group account scope does not match actor context", error.message
    assert_equal "active", @membership.reload.state
  end

  test "detach is denied when the account scope is missing or empty" do
    [nil, ""].each do |account_public_id|
      error =
        assert_raises(GroupAvatarMemberships::Detach::AuthorizationDenied) do
          GroupAvatarMemberships::Detach.call(
            membership: @membership,
            actor: @actor,
            surface: "app",
            subject_public_id: @account_public_id,
            account_public_id: account_public_id,
          )
        end

      assert_equal "group account scope does not match actor context", error.message
    end
    assert_equal "active", @membership.reload.state
  end

  test "detach is denied to a client who does not own the group" do
    stranger = Client.create!(status_id: ClientStatus::ACTIVE, visibility_id: ClientVisibility::USER)
    stranger_account_public_id =
      BaseSelectorBootstrapAuthority.call(surface: :app, principal: stranger).account.public_id

    assert_raises(GroupAvatarMemberships::Detach::AuthorizationDenied) do
      GroupAvatarMemberships::Detach.call(
        membership: @membership,
        actor: stranger,
        surface: "app",
        subject_public_id: stranger_account_public_id,
        account_public_id: stranger_account_public_id,
      )
    end

    assert_equal "active", @membership.reload.state
  end

  test "detaching an already removed membership is idempotent and keeps the first removal time" do
    GroupAvatarMemberships::Detach.call(
      membership: @membership,
      actor: @actor,
      surface: "app",
      subject_public_id: @account_public_id,
      account_public_id: @account_public_id,
    )
    removed_at = @membership.reload.removed_at

    result = GroupAvatarMemberships::Detach.call(
      membership: @membership,
      actor: @actor,
      surface: "app",
      subject_public_id: @account_public_id,
      account_public_id: @account_public_id,
    )

    assert_equal "removed", result.state
    assert_equal removed_at, @membership.reload.removed_at
  end

  test "reorder is denied on a surface other than the group owner's and keeps the position" do
    position = @membership.position

    error =
      assert_raises(GroupAvatarMemberships::Reorder::AuthorizationDenied) do
        GroupAvatarMemberships::Reorder.call(
          membership: @membership,
          position: 5,
          actor: @actor,
          surface: "org",
          subject_public_id: @account_public_id,
          account_public_id: @account_public_id,
        )
      end

    assert_equal "group owner surface does not match actor surface", error.message
    assert_equal position, @membership.reload.position
  end

  test "reorder is denied when the account scope is not the acting subject's own account" do
    position = @membership.position

    error =
      assert_raises(GroupAvatarMemberships::Reorder::AuthorizationDenied) do
        GroupAvatarMemberships::Reorder.call(
          membership: @membership,
          position: 5,
          actor: @actor,
          surface: "app",
          subject_public_id: @account_public_id,
          account_public_id: "another-account-public-id",
        )
      end

    assert_equal "group account scope does not match actor context", error.message
    assert_equal position, @membership.reload.position
  end

  test "reorder accepts position zero, the lowest position the contract allows" do
    GroupAvatarMemberships::Reorder.call(
      membership: @membership,
      position: 4,
      actor: @actor,
      surface: "app",
      subject_public_id: @account_public_id,
      account_public_id: @account_public_id,
    )

    GroupAvatarMemberships::Reorder.call(
      membership: @membership,
      position: 0,
      actor: @actor,
      surface: "app",
      subject_public_id: @account_public_id,
      account_public_id: @account_public_id,
    )

    assert_equal 0, @membership.reload.position
  end

  test "reorder rejects a position that is not an integer before touching the membership" do
    position = @membership.position

    assert_raises(ArgumentError) do
      GroupAvatarMemberships::Reorder.call(
        membership: @membership,
        position: "first",
        actor: @actor,
        surface: "app",
        subject_public_id: @account_public_id,
        account_public_id: @account_public_id,
      )
    end
    assert_raises(TypeError) do
      GroupAvatarMemberships::Reorder.call(
        membership: @membership,
        position: nil,
        actor: @actor,
        surface: "app",
        subject_public_id: @account_public_id,
        account_public_id: @account_public_id,
      )
    end

    assert_equal position, @membership.reload.position
  end

  test "reorder rejects a removed membership" do
    @membership.update!(state: "removed", removed_at: Time.current)

    error =
      assert_raises(ArgumentError) do
        GroupAvatarMemberships::Reorder.call(
          membership: @membership,
          position: 2,
          actor: @actor,
          surface: "app",
          subject_public_id: @account_public_id,
          account_public_id: @account_public_id,
        )
      end

    assert_equal "membership is not active", error.message
  end

  test "reorder rejects a membership of an archived group" do
    position = @membership.position
    @group.update!(state: "archived", archived_at: Time.current)

    error =
      assert_raises(ArgumentError) do
        GroupAvatarMemberships::Reorder.call(
          membership: @membership,
          position: 2,
          actor: @actor,
          surface: "app",
          subject_public_id: @account_public_id,
          account_public_id: @account_public_id,
        )
      end

    assert_equal "group is not active", error.message
    assert_equal position, @membership.reload.position
  end

  test "reorder rejects a membership whose Avatar no longer shares the group's owner" do
    position = @membership.position
    @bootstrap.avatar.current_ownership_period.update!(valid_to: Time.current)
    AvatarOwnershipPeriod.create!(
      avatar: @bootstrap.avatar,
      owner_organization_id: "transitional-owner",
      owner_surface: "org",
      owner_collective_public_id: "bureau-public-id",
      avatar_ownership_status_id: AvatarOwnershipStatus::ACTIVE,
      valid_from: Time.current,
    )

    error =
      assert_raises(ArgumentError) do
        GroupAvatarMemberships::Reorder.call(
          membership: @membership,
          position: 2,
          actor: @actor,
          surface: "app",
          subject_public_id: @account_public_id,
          account_public_id: @account_public_id,
        )
      end

    assert_equal "group and Avatar current owners differ", error.message
    assert_equal position, @membership.reload.position
  end
end
