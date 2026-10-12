# typed: false
# frozen_string_literal: true

require "test_helper"

class AvatarAccessGrantsTest < ActiveSupport::TestCase
  setup do
    @client = Client.create!(status_id: ClientStatus::ACTIVE, visibility_id: ClientVisibility::USER)
    @app = BaseSelectorBootstrapAuthority.call(surface: :app, principal: @client)
    @app.avatar.current_avatar_persona_binding.revoke!(force: true)
    @period = @app.avatar.reload.enterprise_ownership_periods.current.first
  end

  test "issues and evaluates a concrete enterprise Persona grant for the current ownership generation" do
    grant = AvatarAccessGrants::IssueOperation.call(
      ownership_period: @period,
      subject: @app.account,
      capability: "avatar.view",
      granted_by_actor_public_id: @client.public_id,
    )

    assert_instance_of AvatarEnterprisePersonaGrant, grant
    assert AvatarAccessGrantResolver.call(
      avatar: @app.avatar,
      ownership_period: @period,
      subject: @app.account,
      capability: "avatar.view",
    )
    assert_equal @period.id, grant.avatar.enterprise_ownership_periods.current.first.id
  end

  test "a grant is bound to its ownership generation and cannot be issued for closed history" do
    grant = AvatarAccessGrants::IssueOperation.call(
      ownership_period: @period,
      subject: @app.account,
      capability: "avatar.view",
      granted_by_actor_public_id: @client.public_id,
    )
    transition_at = @period.valid_from + 1.second
    @period.update!(valid_to: transition_at)
    AvatarEnterpriseOwnershipPeriod.create!(
      avatar: @app.avatar,
      enterprise_public_id: @app.collective.public_id,
      valid_from: transition_at,
      transferred_by_actor_public_id: @client.public_id,
    )

    assert_not AvatarAccessGrantResolver.call(
      avatar: @app.avatar,
      ownership_period: @period,
      subject: @app.account,
      capability: "avatar.view",
    )
    assert_raises(ArgumentError) do
      AvatarAccessGrants::IssueOperation.call(
        ownership_period: @period,
        subject: @app.account,
        capability: "avatar.update",
        granted_by_actor_public_id: @client.public_id,
      )
    end
    assert_nil grant.reload.revoked_at
  end

  test "a non-owner cannot issue a grant for the current ownership generation" do
    other = Client.create!(status_id: ClientStatus::ACTIVE, visibility_id: ClientVisibility::USER)

    assert_raises(AvatarOwnerMembershipLockService::AuthorizationDenied) do
      AvatarAccessGrants::IssueOperation.call(
        ownership_period: @period,
        subject: @app.account,
        capability: "avatar.view",
        granted_by_actor_public_id: other.public_id,
      )
    end

    assert_equal 0, AvatarEnterprisePersonaGrant.where(avatar_enterprise_ownership_period_id: @period.id).count
  end

  test "a member cannot self-authorize additional grants" do
    @app.account.persona_memberships
      .find_by!(enterprise: @app.collective)
      .update!(membership_kind_id: PersonaMembershipKind::MEMBER)

    assert_raises(AvatarOwnerMembershipLockService::AuthorizationDenied) do
      AvatarAccessGrants::IssueOperation.call(
        ownership_period: @period,
        subject: @app.account,
        capability: "avatar.view",
        granted_by_actor_public_id: @client.public_id,
      )
    end
  end

  test "revocation stops a grant without changing the ownership period" do
    grant = AvatarAccessGrants::IssueOperation.call(
      ownership_period: @period,
      subject: @app.account,
      capability: "avatar.view",
      granted_by_actor_public_id: @client.public_id,
    )
    grant.update!(revoked_at: Time.current)

    assert_not AvatarAccessGrantResolver.call(
      avatar: @app.avatar,
      ownership_period: @period,
      subject: @app.account,
      capability: "avatar.view",
    )
    assert_predicate @period.reload, :current?
  end

  test "issues and evaluates a concrete Bureau Agent grant separately from app grants" do
    operator = Operator.create!(status_id: OperatorStatus::ACTIVE, visibility_id: OperatorVisibility::STAFF)
    org = BaseSelectorBootstrapAuthority.call(surface: :org, principal: operator)
    result = AvatarProvisioning::Create.call(
      actor: operator,
      subject_type: :agent,
      subject: org.account,
      avatar_params: { moniker: "Grant Avatar" },
      handle_params: { handle: "grant-avatar-#{SecureRandom.hex(4)}" },
      owner_surface: "org",
      owner_collective_public_id: org.collective.public_id,
    )

    assert_predicate result, :success?, result.errors.inspect
    avatar = result.avatar
    period = avatar.reload.bureau_ownership_periods.current.first

    grant = AvatarAccessGrants::IssueOperation.call(
      ownership_period: period,
      subject: org.account,
      capability: "avatar.view",
      granted_by_actor_public_id: operator.public_id,
    )

    assert_instance_of AvatarBureauAgentGrant, grant
    assert AvatarAccessGrantResolver.call(
      avatar: avatar,
      ownership_period: period,
      subject: org.account,
      capability: "avatar.view",
    )
    assert_not AvatarAccessGrantResolver.call(
      avatar: @app.avatar,
      ownership_period: @period,
      subject: org.account,
      capability: "avatar.view",
    )
  end

  test "invalid subject and capability values are rejected without generic owner columns" do
    invalid = AvatarEnterprisePersonaGrant.new(
      ownership_period: @period,
      persona_public_id: " ",
      capability: "avatar.unknown",
      granted_by_actor_public_id: @client.public_id,
      granted_at: Time.current,
    )

    assert_not invalid.valid?
    assert_includes invalid.errors.attribute_names, :persona_public_id
    assert_includes invalid.errors.attribute_names, :capability

    columns = AvatarEnterprisePersonaGrant.column_names

    assert_not_includes columns, "subject_type"
    assert_not_includes columns, "owner_type"
    assert_not_includes columns, "ownership_period_type"
  end
end
