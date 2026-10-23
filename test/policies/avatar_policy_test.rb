# typed: false
# frozen_string_literal: true

require "test_helper"

class AvatarPolicyTest < ActiveSupport::TestCase
  setup do
    @client = Client.create!(
      security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE,
      visibility_id: ClientVisibility::USER,
    )
    @bootstrap = BaseSelectorBootstrapAuthority.call(surface: :app, principal: @client)
    @avatar = @bootstrap.avatar
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

  test "active owner membership can view and update the current owned Avatar" do
    policy = AvatarPolicy.new(@avatar, user: @client)

    assert_predicate policy, :show?
    assert_predicate policy, :update?
    assert AvatarPolicy.new(Avatar, user: @client).apply_scope(
      Avatar.all,
      type: :active_record_relation,
    ).exists?(id: @avatar.id)
  end

  test "post-cutover policy reads and scopes by the concrete owner" do
    AvatarRecord.transaction(joinable: false) do
      AvatarOwnershipCutover.create!(
        id: AvatarOwnershipCutover::CUTOVER_ID,
        cutover_at: Time.utc(2030, 1, 1),
      )

      policy = AvatarPolicy.new(@avatar, user: @client)
      scoped = AvatarPolicy.new(Avatar, user: @client).apply_scope(
        Avatar.where(id: @avatar.id),
        type: :active_record_relation,
      )

      assert_predicate policy, :show?
      assert_predicate policy, :update?
      assert_equal [@avatar.id], scoped.pluck(:id)
      assert_instance_of AvatarEnterpriseOwnershipPeriod, @avatar.current_ownership_period

      # Roll back the marker and synthetic graph through the ordinary test transaction.
      raise ActiveRecord::Rollback
    end
  end

  test "a forged legacy owner assignment cannot authorize an Avatar owned by another collective" do
    other = Client.create!(
      security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE,
      visibility_id: ClientVisibility::USER,
    )
    other_bootstrap = BaseSelectorBootstrapAuthority.call(surface: :app, principal: other)
    legacy_owner_assignment = other_bootstrap.avatar.avatar_assignments.create!(
      user: other,
      role: "owner",
    )
    legacy_owner_assignment.update!(user: @client)

    assert_not_predicate AvatarPolicy.new(other_bootstrap.avatar.reload, user: @client), :show?
    assert_not AvatarPolicy.new(Avatar, user: @client).apply_scope(
      Avatar.where(id: other_bootstrap.avatar.id),
      type: :active_record_relation,
    ).exists?
  end

  test "member membership and mismatched surface cannot authorize Avatar access" do
    membership = @bootstrap.account.persona_memberships.find_by!(enterprise: @bootstrap.collective)
    membership.update!(membership_kind_id: PersonaMembershipKind::MEMBER)

    assert_not_predicate AvatarPolicy.new(@avatar, user: @client), :show?

    Actor.install_context!(tld: :com)

    assert_not_predicate AvatarPolicy.new(@avatar, user: @client), :show?
  end
end
