# typed: false
# frozen_string_literal: true

require "test_helper"

class AvatarGroupPolicyTest < ActiveSupport::TestCase
  setup do
    @user = Client.create!(status_id: ClientStatus::ACTIVE, visibility_id: ClientVisibility::USER)
    @bootstrap = BaseSelectorBootstrapAuthority.call(surface: :app, principal: @user)
    install_selected_app_context
  end

  teardown { Actor.clear }

  test "owner membership can list and create account scoped groups" do
    policy = AvatarGroupPolicy.new(AvatarGroup, user: @user)

    assert_predicate policy, :index?
    assert_predicate policy, :create?
  end

  test "non-owner and com actor cannot list or create groups" do
    membership = @bootstrap.account.persona_memberships.find_by!(enterprise: @bootstrap.collective)
    membership.update!(membership_kind_id: PersonaMembershipKind::MEMBER)
    policy = AvatarGroupPolicy.new(AvatarGroup, user: @user)

    assert_not policy.index?
    assert_not policy.create?

    Actor.install_context!(tld: :com)

    assert_not AvatarGroupPolicy.new(AvatarGroup, user: Visitor.new).index?
  end

  test "selected account and owner can show and mutate an active app group" do
    group = create_group
    policy = AvatarGroupPolicy.new(group, user: @user)

    assert_predicate policy, :show?
    assert_predicate policy, :update?
    assert_predicate policy, :destroy?
  end

  test "wrong account surface and owner or archived groups are denied" do
    wrong_surface = create_group(account_surface: "org")
    wrong_account = create_group(account_public_id: "other-account-public-id")
    wrong_owner = create_group(owner_collective_public_id: "other-collective-public-id")
    archived = create_group(state: "archived", archived_at: Time.current)

    assert_not AvatarGroupPolicy.new(wrong_surface, user: @user).show?
    assert_not AvatarGroupPolicy.new(wrong_account, user: @user).show?
    assert_not AvatarGroupPolicy.new(wrong_owner, user: @user).show?
    assert_not AvatarGroupPolicy.new(archived, user: @user).update?
    assert_not AvatarGroupPolicy.new(archived, user: @user).destroy?
    assert_not AvatarGroupPolicy.new(Object.new, user: @user).show?
  end

  test "relation scope keeps only the selected account and current owner groups" do
    own = create_group(name: "Own")
    create_group(name: "Other account", account_public_id: "another-account")
    create_group(name: "Other owner", owner_collective_public_id: "another-collective")

    scoped = AvatarGroupPolicy.new(AvatarGroup, user: @user).apply_scope(
      AvatarGroup.all,
      type: :active_record_relation,
    )

    assert_equal [own.id], scoped.pluck(:id)
  end

  test "relation scope is empty for non-owner actor or missing selected context" do
    group = create_group

    assert_empty AvatarGroupPolicy.new(AvatarGroup, user: Visitor.new).apply_scope(
      AvatarGroup.all,
      type: :active_record_relation,
    )

    Actor.install_context!(selection: Actor::SelectedContext::NULL)

    assert_empty AvatarGroupPolicy.new(AvatarGroup, user: @user).apply_scope(
      AvatarGroup.where(id: group.id),
      type: :active_record_relation,
    )
  end

  private

  def create_group(account_surface: "app", account_public_id: @bootstrap.account.public_id,
                   owner_surface: "app", owner_collective_public_id: @bootstrap.collective.public_id,
                   state: "active", archived_at: nil, name: "Policy Group")
    group = AvatarGroup.create!(
      account_surface: account_surface,
      account_public_id: account_public_id,
      name: "#{name}-#{SecureRandom.hex(3)}",
      state: state,
      archived_at: archived_at,
    )
    AvatarGroupOwnershipPeriod.create!(
      avatar_group: group,
      owner_surface: owner_surface,
      owner_collective_public_id: owner_collective_public_id,
      valid_from: Time.current,
    )
    group
  end

  def install_selected_app_context
    Actor.install_context!(
      tld: :app,
      selection: Actor::SelectedContext.new(
        account_public_id: @bootstrap.account.public_id,
        collective_public_id: @bootstrap.collective.public_id,
        collective_unit_public_id: @bootstrap.unit.public_id,
      ),
    )
  end
end
