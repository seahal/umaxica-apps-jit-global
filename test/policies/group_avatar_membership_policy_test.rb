# typed: false
# frozen_string_literal: true

require "test_helper"

class GroupAvatarMembershipPolicyTest < ActiveSupport::TestCase
  setup do
    @user = Client.create!(status_id: ClientStatus::ACTIVE, visibility_id: ClientVisibility::USER)
    @bootstrap = BaseSelectorBootstrapAuthority.call(surface: :app, principal: @user)
    @group = AvatarGroup.create!(
      account_surface: "app",
      account_public_id: @bootstrap.account.public_id,
      name: "Membership policy group",
      state: "active",
    )
    AvatarGroupOwnershipPeriod.create!(
      avatar_group: @group,
      owner_surface: "app",
      owner_collective_public_id: @bootstrap.collective.public_id,
      valid_from: Time.current,
    )
    Actor.install_context!(
      tld: :app,
      selection: Actor::SelectedContext.new(
        account_public_id: @bootstrap.account.public_id,
        collective_public_id: @bootstrap.collective.public_id,
        collective_unit_public_id: @bootstrap.unit.public_id,
      ),
    )
  end

  teardown { Actor.clear }

  test "owner can attach, reorder, and detach a membership with matching owner" do
    membership = new_membership(avatar: @bootstrap.avatar)
    policy = GroupAvatarMembershipPolicy.new(membership, user: @user)

    assert_predicate policy, :create?
    assert_predicate policy, :update?
    assert_predicate policy, :destroy?
  end

  test "non-owner wrong account and com surface are denied" do
    wrong_group = AvatarGroup.create!(
      account_surface: "app", account_public_id: "other-account", name: "Other", state: "active",
    )
    AvatarGroupOwnershipPeriod.create!(
      avatar_group: wrong_group, owner_surface: "app",
      owner_collective_public_id: @bootstrap.collective.public_id, valid_from: Time.current,
    )
    membership = new_membership(group: wrong_group, avatar: @bootstrap.avatar)
    assert_not GroupAvatarMembershipPolicy.new(membership, user: @user).create?
    assert_not GroupAvatarMembershipPolicy.new(new_membership(avatar: @bootstrap.avatar), user: Visitor.new).create?

    Actor.install_context!(tld: :com)
    assert_not GroupAvatarMembershipPolicy.new(
      new_membership(avatar: @bootstrap.avatar), user: Visitor.new,
    ).create?
  end

  test "membership roles cannot substitute for ownership or permissions" do
    persona_membership = @bootstrap.account.persona_memberships.find_by!(enterprise: @bootstrap.collective)
    persona_membership.update!(membership_kind_id: PersonaMembershipKind::MEMBER)

    assert_not GroupAvatarMembershipPolicy.new(
      new_membership(avatar: @bootstrap.avatar), user: @user,
    ).create?
  end

  test "a stale cross-owner membership is denied for attach but remains detachable by group owner" do
    other = Client.create!(status_id: ClientStatus::ACTIVE, visibility_id: ClientVisibility::USER)
    other_avatar = BaseSelectorBootstrapAuthority.call(surface: :app, principal: other).avatar
    membership = new_membership(avatar: other_avatar)
    policy = GroupAvatarMembershipPolicy.new(membership, user: @user)

    assert_not policy.create?
    assert_predicate policy, :destroy?
  end

  test "removed membership cannot be reordered or detached" do
    membership = new_membership(avatar: @bootstrap.avatar, state: "removed", removed_at: Time.current)
    policy = GroupAvatarMembershipPolicy.new(membership, user: @user)

    assert_not policy.update?
    assert_not policy.destroy?
  end

  private

  def new_membership(group: @group, avatar:, state: "active", removed_at: nil)
    GroupAvatarMembership.new(
      avatar_group: group,
      avatar: avatar,
      role: "member",
      position: 0,
      state: state,
      assigned_at: 1.minute.ago,
      removed_at: removed_at,
    )
  end
end
