# typed: false
# frozen_string_literal: true

require "test_helper"

class AvatarPermissionResolverTest < ActiveSupport::TestCase
  setup do
    @client = Client.create!(status_id: ClientStatus::ACTIVE, visibility_id: ClientVisibility::USER)
    @app = BaseSelectorBootstrapAuthority.call(surface: :app, principal: @client)
    @operator = Operator.create!(status_id: OperatorStatus::ACTIVE, visibility_id: OperatorVisibility::STAFF)
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

    other = Client.create!(status_id: ClientStatus::ACTIVE, visibility_id: ClientVisibility::USER)
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
      actor: Visitor.new,
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

end
