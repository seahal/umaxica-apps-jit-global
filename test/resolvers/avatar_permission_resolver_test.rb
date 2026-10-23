# typed: false
# frozen_string_literal: true

require "test_helper"

class AvatarPermissionResolverTest < ActiveSupport::TestCase
  setup do
    @client = Client.create!(
      security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE,
      visibility_id: ClientVisibility::USER,
    )
    @app = BaseSelectorBootstrapAuthority.call(surface: :app, principal: @client)
    @operator = Operator.create!(
      security_mode_id: SecurityModeConfigurable::ADVANCED,
      status_id: OperatorStatus::ACTIVE, visibility_id: OperatorVisibility::STAFF,
    )
    @org = BaseSelectorBootstrapAuthority.call(surface: :org, principal: @operator)
  end

  test "active app and org owners resolve the same Avatar permissions" do
    assert AvatarPermissionResolver.call(
      actor: @client,
      surface: :app,
      subject_public_id: @app.account.public_id,
      owner_collective_public_id: @app.collective.public_id,
      permission: "avatar.group.attach",
    )
    assert AvatarPermissionResolver.call(
      actor: @operator,
      surface: :org,
      subject_public_id: @org.account.public_id,
      owner_collective_public_id: @org.collective.public_id,
      permission: "avatar.group.attach",
    )
  end

  test "member guest inactive and cross-principal memberships grant no owner permission" do
    app_membership = @app.account.persona_memberships.find_by!(enterprise: @app.collective)
    app_membership.update!(membership_kind_id: PersonaMembershipKind::MEMBER)

    assert_not AvatarPermissionResolver.call(
      actor: @client,
      surface: :app,
      subject_public_id: @app.account.public_id,
      owner_collective_public_id: @app.collective.public_id,
      permission: "avatar.update",
    )

    app_membership.update!(membership_kind_id: PersonaMembershipKind::GUEST)

    assert_not AvatarPermissionResolver.call(
      actor: @client,
      surface: :app,
      subject_public_id: @app.account.public_id,
      owner_collective_public_id: @app.collective.public_id,
      permission: "avatar.group.manage",
    )

    app_membership.update!(membership_kind_id: PersonaMembershipKind::OWNER)
    app_membership.update!(membership_state_id: PersonaMembershipState::NOTHING)

    assert_not AvatarPermissionResolver.call(
      actor: @client,
      surface: :app,
      subject_public_id: @app.account.public_id,
      owner_collective_public_id: @app.collective.public_id,
      permission: "avatar.view",
    )

    other = Client.create!(
      security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE,
      visibility_id: ClientVisibility::USER,
    )
    BaseSelectorBootstrapAuthority.call(surface: :app, principal: other)

    assert_not AvatarPermissionResolver.call(
      actor: other,
      surface: :app,
      subject_public_id: @app.account.public_id,
      owner_collective_public_id: @app.collective.public_id,
      permission: "avatar.view",
    )
  end

  test "com and unsupported membership permissions fail closed" do
    assert_not AvatarPermissionResolver.call(
      actor: Visitor.new(security_mode_id: SecurityModeConfigurable::NORMAL),
      surface: :com,
      subject_public_id: "individual-public-id",
      owner_collective_public_id: "company-public-id",
      permission: "avatar.view",
    )

    assert_raises(ArgumentError) do
      AvatarPermissionResolver.call(
        actor: @client,
        surface: :app,
        subject_public_id: @app.account.public_id,
        owner_collective_public_id: @app.collective.public_id,
        permission: "avatar.unknown",
      )
    end
  end

  test "an explicit generation-bound grant authorizes Avatar use without granting management authority" do
    period = @app.avatar.reload.enterprise_ownership_periods.current.first
    AvatarAccessGrants::IssueOperation.call(
      ownership_period: period,
      subject: @app.account,
      capability: "avatar.view",
      granted_by_actor_public_id: @client.public_id,
      granting_subject_public_id: @app.account.public_id,
    )

    membership = @app.account.persona_memberships.find_by!(enterprise: @app.collective)
    membership.update!(membership_kind_id: PersonaMembershipKind::MEMBER)

    assert AvatarPermissionResolver.call(
      actor: @client,
      surface: :app,
      subject_public_id: @app.account.public_id,
      owner_collective_public_id: @app.collective.public_id,
      permission: "avatar.view",
      avatar: @app.avatar,
    )
    assert_not AvatarPermissionResolver.call(
      actor: @client,
      surface: :app,
      subject_public_id: @app.account.public_id,
      owner_collective_public_id: @app.collective.public_id,
      permission: "avatar.group.manage",
    )
  end
end
