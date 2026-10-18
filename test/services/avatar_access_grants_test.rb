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
      granting_subject_public_id: @app.account.public_id,
    )

    assert_instance_of AvatarEnterprisePersonaGrant, grant
    assert AvatarAccessGrantResolver.call(
      avatar: @app.avatar,
      ownership_period: @period,
      subject: @app.account,
      capability: "avatar.view",
    )
    current_period = AvatarEnterpriseOwnershipPeriod.current.find_by!(avatar_id: @app.avatar.id)

    assert_equal @period.id, current_period.id
    assert_equal @period.id, grant.avatar_enterprise_ownership_period_id
  end

  test "a grant is bound to its ownership generation and cannot be issued for closed history" do
    grant = AvatarAccessGrants::IssueOperation.call(
      ownership_period: @period,
      subject: @app.account,
      capability: "avatar.view",
      granted_by_actor_public_id: @client.public_id,
      granting_subject_public_id: @app.account.public_id,
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
        granting_subject_public_id: @app.account.public_id,
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
        granting_subject_public_id: @app.account.public_id,
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
        granting_subject_public_id: @app.account.public_id,
      )
    end
  end

  test "revocation stops a grant without changing the ownership period" do
    grant = AvatarAccessGrants::IssueOperation.call(
      ownership_period: @period,
      subject: @app.account,
      capability: "avatar.view",
      granted_by_actor_public_id: @client.public_id,
      granting_subject_public_id: @app.account.public_id,
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
      granting_subject_public_id: org.account.public_id,
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
    assert_not_includes columns, "expires_at"
    assert_not_includes AvatarBureauAgentGrant.column_names, "expires_at"
  end

  test "an owner can grant a current generation to another concrete member" do
    recipient_actor = Client.create!(status_id: ClientStatus::ACTIVE, visibility_id: ClientVisibility::USER)
    recipient = BaseSelectorBootstrapAuthority.call(surface: :app, principal: recipient_actor)
    CollectiveMembership::Grant.call(
      account: recipient.account,
      collective: @app.collective,
      unit: @app.collective.root_units.first,
      kind_id: PersonaMembershipKind::MEMBER,
    )

    grant = AvatarAccessGrants::IssueOperation.call(
      ownership_period: @period,
      subject: recipient.account,
      capability: "avatar.view",
      granted_by_actor_public_id: @client.public_id,
      granting_subject_public_id: @app.account.public_id,
    )

    assert_equal recipient.account.public_id, grant.persona_public_id
    assert AvatarAccessGrantResolver.call(
      avatar: @app.avatar,
      ownership_period: @period,
      subject: recipient.account,
      capability: "avatar.view",
    )
  end

  test "a grant recipient without owner authority cannot issue another grant" do
    recipient_actor = Client.create!(status_id: ClientStatus::ACTIVE, visibility_id: ClientVisibility::USER)
    recipient = BaseSelectorBootstrapAuthority.call(surface: :app, principal: recipient_actor)

    grant = AvatarAccessGrants::IssueOperation.call(
      ownership_period: @period,
      subject: recipient.account,
      capability: "avatar.view",
      granted_by_actor_public_id: @client.public_id,
      granting_subject_public_id: @app.account.public_id,
    )

    assert AvatarAccessGrantResolver.call(
      avatar: @app.avatar,
      ownership_period: @period,
      subject: recipient.account,
      capability: "avatar.view",
    )
    assert_instance_of AvatarEnterprisePersonaGrant, grant

    assert_no_difference(
      -> { AvatarEnterprisePersonaGrant.where(avatar_enterprise_ownership_period_id: @period.id).count },
    ) do
      assert_raises(AvatarOwnerMembershipLockService::AuthorizationDenied) do
        AvatarAccessGrants::IssueOperation.call(
          ownership_period: @period,
          subject: @app.account,
          capability: "avatar.view",
          granted_by_actor_public_id: recipient_actor.public_id,
          granting_subject_public_id: recipient.account.public_id,
        )
      end
    end
  end

  test "independent Persona grants allow multiple recipients and multiple Avatars without owner membership" do
    recipient_a_actor = Client.create!(status_id: ClientStatus::ACTIVE, visibility_id: ClientVisibility::USER)
    recipient_a = BaseSelectorBootstrapAuthority.call(surface: :app, principal: recipient_a_actor)
    recipient_b_actor = Client.create!(status_id: ClientStatus::ACTIVE, visibility_id: ClientVisibility::USER)
    recipient_b = BaseSelectorBootstrapAuthority.call(surface: :app, principal: recipient_b_actor)
    second_owner_actor = Client.create!(status_id: ClientStatus::ACTIVE, visibility_id: ClientVisibility::USER)
    second_owner = BaseSelectorBootstrapAuthority.call(surface: :app, principal: second_owner_actor)

    assert_not PersonaMembership.exists?(persona_id: recipient_a.account.id, enterprise_id: @app.collective.id)
    assert_not PersonaMembership.exists?(persona_id: recipient_b.account.id, enterprise_id: @app.collective.id)
    assert_not PersonaMembership.exists?(
      persona_id: recipient_b.account.id,
      enterprise_id: second_owner.collective.id,
    )

    AvatarAccessGrants::IssueOperation.call(
      ownership_period: @period,
      subject: recipient_a.account,
      capability: "avatar.view",
      granted_by_actor_public_id: @client.public_id,
      granting_subject_public_id: @app.account.public_id,
    )
    AvatarAccessGrants::IssueOperation.call(
      ownership_period: @period,
      subject: recipient_b.account,
      capability: "avatar.view",
      granted_by_actor_public_id: @client.public_id,
      granting_subject_public_id: @app.account.public_id,
    )

    second_period = second_owner.avatar.reload.enterprise_ownership_periods.current.first
    AvatarAccessGrants::IssueOperation.call(
      ownership_period: second_period,
      subject: recipient_b.account,
      capability: "avatar.view",
      granted_by_actor_public_id: second_owner_actor.public_id,
      granting_subject_public_id: second_owner.account.public_id,
    )

    assert AvatarAccessGrantResolver.call(
      avatar: @app.avatar,
      ownership_period: @period,
      subject: recipient_a.account,
      capability: "avatar.view",
    )
    assert AvatarAccessGrantResolver.call(
      avatar: @app.avatar,
      ownership_period: @period,
      subject: recipient_b.account,
      capability: "avatar.view",
    )
    assert AvatarAccessGrantResolver.call(
      avatar: second_owner.avatar,
      ownership_period: second_period,
      subject: recipient_b.account,
      capability: "avatar.view",
    )
    assert_not AvatarAccessGrantResolver.call(
      avatar: second_owner.avatar,
      ownership_period: second_period,
      subject: recipient_a.account,
      capability: "avatar.view",
    )
  end

  test "a Grant is effective at granted_at and cannot confer another capability" do
    granted_at = Time.current.change(usec: 0).advance(minutes: 1)
    grant = AvatarAccessGrants::IssueOperation.call(
      ownership_period: @period,
      subject: @app.account,
      capability: "avatar.view",
      granted_by_actor_public_id: @client.public_id,
      granting_subject_public_id: @app.account.public_id,
      granted_at: granted_at,
    )

    assert_not AvatarAccessGrantResolver.call(
      avatar: @app.avatar,
      ownership_period: @period,
      subject: @app.account,
      capability: "avatar.view",
      at: granted_at - Rational(1, 1_000_000),
    )
    assert AvatarAccessGrantResolver.call(
      avatar: @app.avatar,
      ownership_period: @period,
      subject: @app.account,
      capability: "avatar.view",
      at: granted_at,
    )
    %w(avatar.update avatar.grant.manage avatar.transfer.request avatar.transfer.accept avatar.transfer.cancel)
      .each do |capability|
      assert_not AvatarAccessGrantResolver.call(
        avatar: @app.avatar,
        ownership_period: @period,
        subject: @app.account,
        capability: capability,
        at: granted_at,
      )
    end
    assert_equal "avatar.view", grant.capability

    assert_no_difference -> { AvatarEnterprisePersonaGrant.count } do
      assert_raises(ArgumentError) do
        AvatarAccessGrants::IssueOperation.call(
          ownership_period: @period,
          subject: @app.account,
          capability: "avatar.transfer.request",
          granted_by_actor_public_id: @client.public_id,
          granting_subject_public_id: @app.account.public_id,
        )
      end
    end
  end

  test "an Agent cannot receive a Grant for an Enterprise ownership period" do
    operator = Operator.create!(status_id: OperatorStatus::ACTIVE, visibility_id: OperatorVisibility::STAFF)
    org = BaseSelectorBootstrapAuthority.call(surface: :org, principal: operator)

    assert_raises(ArgumentError) do
      AvatarAccessGrants::IssueOperation.call(
        ownership_period: @period,
        subject: org.account,
        capability: "avatar.view",
        granted_by_actor_public_id: @client.public_id,
        granting_subject_public_id: @app.account.public_id,
      )
    end
    assert_not AvatarAccessGrantResolver.call(
      avatar: @app.avatar,
      ownership_period: @period,
      subject: org.account,
      capability: "avatar.view",
    )
  end
end
