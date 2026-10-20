# frozen_string_literal: true

require "test_helper"

class AvatarEnterprisePersonaGrantUniquenessTest < ActiveSupport::TestCase
  test "AvatarEnterprisePersonaGrant preserves history capability scope and raw DB refusal" do
    actor = Client.create!(status_id: ClientStatus::ACTIVE, visibility_id: ClientVisibility::USER)
    bootstrap = BaseSelectorBootstrapAuthority.call(surface: :app, principal: actor)
    avatar = bootstrap.avatar
    period = avatar.enterprise_ownership_periods.current.sole

    attributes = { ownership_period: period,
                   persona_public_id: bootstrap.account.public_id,
                   capability: "avatar.view",
                   granted_by_actor_public_id: actor.public_id,
                   granted_by_surface: "app",
                   granted_at: Avatar.database_now, }

    first = AvatarEnterprisePersonaGrant.create!(attributes)
    other = AvatarEnterprisePersonaGrant.create!(attributes.merge(capability: "avatar.update"))

    assert_equal "avatar.update", other.reload.capability
    error =
      assert_raises(ActiveRecord::RecordNotUnique) do
        AvatarEnterprisePersonaGrant.transaction(requires_new: true) {
          AvatarEnterprisePersonaGrant.new(attributes).save!(validate: false)
        }
      end
    assert_instance_of PG::UniqueViolation, error.cause
    2.times do
      history = AvatarEnterprisePersonaGrant.create!(attributes.merge(revoked_at: Avatar.database_now))

      assert_predicate history.revoked_at, :present?
    end
    first.update!(revoked_at: Avatar.database_now)
    replacement = AvatarAccessGrants::IssueOperation.call(
      ownership_period: period, subject: bootstrap.account, capability: "avatar.view",
      granted_by_actor_public_id: actor.public_id, granting_subject_public_id: bootstrap.account.public_id,
    )

    assert_predicate replacement, :persisted?
  end

  test "AvatarEnterprisePersonaGrant rejects only an active matching capability tuple" do
    actor = Client.create!(status_id: ClientStatus::ACTIVE, visibility_id: ClientVisibility::USER)
    bootstrap = BaseSelectorBootstrapAuthority.call(surface: :app, principal: actor)
    avatar = bootstrap.avatar
    period = avatar.enterprise_ownership_periods.current.sole

    attributes = { ownership_period: period,
                   persona_public_id: bootstrap.account.public_id,
                   capability: "avatar.view",
                   granted_by_actor_public_id: actor.public_id,
                   granted_by_surface: "app",
                   granted_at: Avatar.database_now, }

    first = AvatarEnterprisePersonaGrant.create!(attributes)
    candidate = AvatarEnterprisePersonaGrant.new(attributes)

    assert_not candidate.valid?
    assert candidate.errors.of_kind?(:persona_public_id, :taken)
    assert_raises(ActiveRecord::RecordInvalid) { candidate.save! }
    assert_predicate candidate, :new_record?
    candidate.revoked_at = Avatar.database_now

    assert_predicate candidate, :valid?
    candidate.save!

    assert_nil first.reload.revoked_at
  end
end

class AvatarBureauAgentGrantUniquenessTest < ActiveSupport::TestCase
  test "AvatarBureauAgentGrant preserves history capability scope and raw DB refusal" do
    actor = Operator.create!(status_id: OperatorStatus::ACTIVE, visibility_id: OperatorVisibility::STAFF)
    bootstrap = BaseSelectorBootstrapAuthority.call(surface: :org, principal: actor)
    created = AvatarProvisioning::Create.call(
      actor: actor, subject_type: :agent, subject: bootstrap.account,
      avatar_params: { moniker: "Grant contract" }, handle_params: { handle: "grant-contract-org" },
      owner_surface: "org", owner_collective_public_id: bootstrap.collective.public_id,
    )

    assert_predicate created, :success?
    avatar = created.avatar
    period = avatar.bureau_ownership_periods.current.sole

    attributes = { ownership_period: period,
                   agent_public_id: bootstrap.account.public_id,
                   capability: "avatar.view",
                   granted_by_actor_public_id: actor.public_id,
                   granted_by_surface: "org",
                   granted_at: Avatar.database_now, }

    first = AvatarBureauAgentGrant.create!(attributes)
    other = AvatarBureauAgentGrant.create!(attributes.merge(capability: "avatar.update"))

    assert_equal "avatar.update", other.reload.capability
    error =
      assert_raises(ActiveRecord::RecordNotUnique) do
        AvatarBureauAgentGrant.transaction(requires_new: true) {
          AvatarBureauAgentGrant.new(attributes).save!(validate: false)
        }
      end
    assert_instance_of PG::UniqueViolation, error.cause
    2.times do
      history = AvatarBureauAgentGrant.create!(attributes.merge(revoked_at: Avatar.database_now))

      assert_predicate history.revoked_at, :present?
    end
    first.update!(revoked_at: Avatar.database_now)
    replacement = AvatarAccessGrants::IssueOperation.call(
      ownership_period: period, subject: bootstrap.account, capability: "avatar.view",
      granted_by_actor_public_id: actor.public_id, granting_subject_public_id: bootstrap.account.public_id,
    )

    assert_predicate replacement, :persisted?
  end

  test "AvatarBureauAgentGrant rejects only an active matching capability tuple" do
    actor = Operator.create!(status_id: OperatorStatus::ACTIVE, visibility_id: OperatorVisibility::STAFF)
    bootstrap = BaseSelectorBootstrapAuthority.call(surface: :org, principal: actor)
    created = AvatarProvisioning::Create.call(
      actor: actor, subject_type: :agent, subject: bootstrap.account,
      avatar_params: { moniker: "Grant contract" }, handle_params: { handle: "grant-contract-org" },
      owner_surface: "org", owner_collective_public_id: bootstrap.collective.public_id,
    )

    assert_predicate created, :success?
    avatar = created.avatar
    period = avatar.bureau_ownership_periods.current.sole

    attributes = { ownership_period: period,
                   agent_public_id: bootstrap.account.public_id,
                   capability: "avatar.view",
                   granted_by_actor_public_id: actor.public_id,
                   granted_by_surface: "org",
                   granted_at: Avatar.database_now, }

    first = AvatarBureauAgentGrant.create!(attributes)
    candidate = AvatarBureauAgentGrant.new(attributes)

    assert_not candidate.valid?
    assert candidate.errors.of_kind?(:agent_public_id, :taken)
    assert_raises(ActiveRecord::RecordInvalid) { candidate.save! }
    assert_predicate candidate, :new_record?
    candidate.revoked_at = Avatar.database_now

    assert_predicate candidate, :valid?
    candidate.save!

    assert_nil first.reload.revoked_at
  end
end
