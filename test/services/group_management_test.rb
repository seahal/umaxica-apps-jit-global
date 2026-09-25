# typed: false
# frozen_string_literal: true

require "test_helper"

class GroupManagementTest < ActiveSupport::TestCase
  test "creates an account scoped active group" do
    actor = Client.create!(status_id: ClientStatus::ACTIVE, visibility_id: ClientVisibility::USER)
    bootstrap = BaseSelectorBootstrapAuthority.call(surface: :app, principal: actor)
    group = GroupManagement::Create.call(
      account_surface: "app",
      account_public_id: bootstrap.account.public_id,
      owner_surface: "app",
      owner_collective_public_id: bootstrap.collective.public_id,
      actor: actor,
      subject_public_id: bootstrap.account.public_id,
      name: "Core team",
      description: "Avatar container",
    )

    assert_predicate group, :persisted?
    assert_equal "app", group.account_surface
    assert_equal bootstrap.account.public_id, group.account_public_id
    assert_equal "active", group.state
    assert_equal "app", group.current_ownership_period.owner_surface
    assert_equal bootstrap.collective.public_id, group.current_ownership_period.owner_collective_public_id
  end

  test "requires an explicit app or org owner for a new group" do
    error =
      assert_raises(ArgumentError) do
        GroupManagement::Create.call(
          account_surface: "app",
          account_public_id: "account-public-id",
          name: "Unowned group",
        )
      end

    assert_match(/owner_surface/, error.message)
  end

  test "rejects com as the owner surface even when the account scope is com" do
    actor = Object.new
    error =
      assert_raises(ArgumentError) do
        GroupManagement::Create.call(
          account_surface: "com",
          account_public_id: "account-public-id",
          owner_surface: "com",
          owner_collective_public_id: "company-public-id",
          actor: actor,
          subject_public_id: "account-public-id",
          name: "Unsupported owner",
        )
      end

    assert_equal "group account context is invalid", error.message
    assert_equal 0, AvatarGroup.where(name: "Unsupported owner").count
  end

  test "archives group instead of deleting it" do
    context = owned_group_context(name: "Archive target")

    GroupManagement::Archive.call(**group_authorization(context))

    assert_equal "archived", context.fetch(:group).reload.state
    assert_predicate context.fetch(:group).archived_at, :present?
  end

  test "updates the name and description of an active group" do
    context = owned_group_context(name: "Before")
    group = context.fetch(:group)

    result = GroupManagement::Update.call(
      group: group,
      attributes: { name: "After", description: "Updated description", state: "archived" },
      **group_authorization(context).except(:group),
    )

    assert_equal group.id, result.id
    assert_equal "After", group.reload.name
    assert_equal "Updated description", group.description
    assert_equal "active", group.state
  end

  test "does not update an archived group" do
    context = owned_group_context(name: "Archived")
    group = context.fetch(:group)
    group.update_columns(state: "archived", archived_at: Time.current)
    group.reload

    error =
      assert_raises(ArgumentError) do
        GroupManagement::Update.call(
          group: group,
          attributes: { name: "Changed" },
          **group_authorization(context).except(:group),
        )
      end

    assert_equal "group is archived", error.message
    assert_equal "Archived", group.reload.name
  end

  test "member membership cannot update a Group despite its account scope" do
    context = owned_group_context(name: "Owner check")
    context.fetch(:bootstrap).account.persona_memberships
      .find_by!(enterprise: context.fetch(:bootstrap).collective)
      .update!(membership_kind_id: PersonaMembershipKind::MEMBER)

    error =
      assert_raises(StandardError) do
        GroupManagement::Update.call(
          group: context.fetch(:group),
          attributes: { name: "Unauthorized" },
          **group_authorization(context).except(:group),
        )
      end

    assert_equal "avatar.group.manage permission required", error.message
    assert_equal "Owner check", context.fetch(:group).reload.name
  end

  test "principal completed by sign-up as VERIFIED_WITH_SIGN_UP can create a Group" do
    actor = Client.create!(status_id: ClientStatus::VERIFIED_WITH_SIGN_UP, visibility_id: ClientVisibility::USER)
    bootstrap = BaseSelectorBootstrapAuthority.call(surface: :app, principal: actor)

    group = GroupManagement::Create.call(
      account_surface: "app",
      account_public_id: bootstrap.account.public_id,
      owner_surface: "app",
      owner_collective_public_id: bootstrap.collective.public_id,
      actor: actor,
      subject_public_id: bootstrap.account.public_id,
      name: "Signed-up owner",
    )

    assert_predicate group, :persisted?
    assert_predicate bootstrap.avatar, :persisted?
  end

  test "login-blocked RESERVED principal cannot create a Group" do
    context = owned_group_context(name: "Reserved owner source")
    client = context.fetch(:actor)
    client.update!(status_id: ClientStatus::RESERVED)

    assert_no_difference -> { AvatarGroup.count } do
      error =
        assert_raises(GroupManagement::Create::AuthorizationDenied) do
          GroupManagement::Create.call(
            account_surface: "app",
            account_public_id: context.fetch(:bootstrap).account.public_id,
            owner_surface: "app",
            owner_collective_public_id: context.fetch(:bootstrap).collective.public_id,
            actor: client,
            subject_public_id: context.fetch(:bootstrap).account.public_id,
            name: "Must not be created",
          )
        end

      assert_equal "Avatar owner actor must be active", error.message
    end
  end

  test "administratively locked principal cannot create a Group" do
    context = owned_group_context(name: "Locked owner source")
    operator = Operator.create!(status_id: OperatorStatus::ACTIVE, visibility_id: OperatorVisibility::STAFF)
    client = context.fetch(:actor)
    client.update!(
      access_state: AdministrativeAccessLockable::ACCESS_STATE_ADMIN_LOCKED,
      admin_locked_at: Time.current,
      admin_locked_by_operator_id: operator.id,
      admin_locked_reason_code: "security_incident",
    )

    assert_no_difference -> { AvatarGroup.count } do
      error =
        assert_raises(GroupManagement::Create::AuthorizationDenied) do
          GroupManagement::Create.call(
            account_surface: "app",
            account_public_id: context.fetch(:bootstrap).account.public_id,
            owner_surface: "app",
            owner_collective_public_id: context.fetch(:bootstrap).collective.public_id,
            actor: client,
            subject_public_id: context.fetch(:bootstrap).account.public_id,
            name: "Must not be created",
          )
        end

      assert_equal "Avatar owner actor must be active", error.message
    end
  end

  private

  def owned_group_context(name:)
    actor = Client.create!(status_id: ClientStatus::ACTIVE, visibility_id: ClientVisibility::USER)
    bootstrap = BaseSelectorBootstrapAuthority.call(surface: :app, principal: actor)
    group = AvatarGroup.create!(
      account_surface: "app", account_public_id: bootstrap.account.public_id,
      name: name, state: "active",
    )
    AvatarGroupOwnershipPeriod.create!(
      avatar_group: group, owner_surface: "app",
      owner_collective_public_id: bootstrap.collective.public_id, valid_from: Time.current,
    )
    { actor: actor, bootstrap: bootstrap, group: group }
  end

  def group_authorization(context)
    bootstrap = context.fetch(:bootstrap)
    {
      group: context.fetch(:group),
      actor: context.fetch(:actor),
      surface: "app",
      subject_public_id: bootstrap.account.public_id,
      account_public_id: bootstrap.account.public_id,
    }
  end
end
