# typed: false
# frozen_string_literal: true

require "test_helper"

class AvatarProvisioningCreateTest < ActiveSupport::TestCase
  test "creates Avatar and initial owner period in one transaction without an owner assignment" do
    user = Client.create!(status_id: ClientStatus::ACTIVE, visibility_id: ClientVisibility::USER)
    bootstrap = BaseSelectorBootstrapAuthority.call(surface: :app, principal: user)
    bootstrap.avatar.current_avatar_persona_binding.revoke!(force: true)

    assert_difference -> { Avatar.count }, 1 do
      assert_difference -> { Handle.count }, 1 do
        assert_difference -> { AvatarPersonaBinding.active.count }, 1 do
          assert_no_difference -> { AvatarAssignment.where(role: "owner").count } do
            assert_difference -> { AvatarOwnershipPeriod.current.count }, 1 do
              result = AvatarProvisioning::Create.call(
                actor: user,
                subject_type: :persona,
                subject: bootstrap.account,
                avatar_params: { moniker: "Provisioned" },
                handle_params: { handle: "provisioned" },
                owner_surface: "app",
                owner_collective_public_id: bootstrap.collective.public_id,
              )

              assert_predicate result, :success?
              assert_equal "Provisioned", result.avatar.moniker
              assert_equal "active", result.avatar.lifecycle_state.key
              assert_equal bootstrap.account, result.binding.persona
              assert_equal result.avatar, bootstrap.account.reload.current_avatar
              assert_equal "app", result.avatar.current_ownership_period.owner_surface
              assert_equal bootstrap.collective.public_id,
                           result.avatar.current_ownership_period.owner_collective_public_id
              assert_predicate result.avatar.current_ownership_period, :current?
              concrete_period = result.avatar.reload.enterprise_ownership_periods.current.first

              assert_equal bootstrap.collective.public_id, concrete_period.enterprise_public_id
              assert_equal result.avatar.created_at, concrete_period.valid_from
            end
          end
        end
      end
    end
  end

  test "post-cutover provisioning writes only the concrete ownership source" do
    user = Client.create!(status_id: ClientStatus::ACTIVE, visibility_id: ClientVisibility::USER)
    bootstrap = BaseSelectorBootstrapAuthority.call(surface: :app, principal: user)
    bootstrap.avatar.current_avatar_persona_binding.revoke!(force: true)

    AvatarRecord.transaction(joinable: false) do
      AvatarOwnershipCutover.create!(
        id: AvatarOwnershipCutover::CUTOVER_ID,
        cutover_at: Time.utc(2030, 1, 1),
      )

      result = AvatarProvisioning::Create.call(
        actor: user,
        subject_type: :persona,
        subject: bootstrap.account,
        avatar_params: { moniker: "Cutover Avatar" },
        handle_params: { handle: "post-cutover-#{SecureRandom.hex(6)}" },
        owner_surface: "app",
        owner_collective_public_id: bootstrap.collective.public_id,
      )

      assert_predicate result, :success?, result.errors.inspect
      avatar = result.avatar
      period = avatar.enterprise_ownership_periods.current.sole

      assert_equal 0, avatar.avatar_ownership_periods.count
      assert_equal bootstrap.collective.public_id, period.enterprise_public_id
      assert_equal avatar.created_at, period.valid_from
      assert_equal period, avatar.current_ownership_period

      # Roll back the marker and synthetic graph through the ordinary test transaction.
      raise ActiveRecord::Rollback
    end
  end

  test "handle conflict rolls back the avatar graph" do
    user = Client.create!(status_id: ClientStatus::ACTIVE, visibility_id: ClientVisibility::USER)
    bootstrap = BaseSelectorBootstrapAuthority.call(surface: :app, principal: user)
    bootstrap.avatar.current_avatar_persona_binding.revoke!(force: true)
    Handle.create!(handle: "conflict-aaaaaaaa", cooldown_until: Time.current, is_system: false)

    SecureRandom.stub(:alphanumeric, "AAAAAAAA") do
      assert_no_difference -> {
        Avatar.count + AvatarPersonaBinding.count + AvatarAssignment.count
      } do
        result = AvatarProvisioning::Create.call(
          actor: user,
          subject_type: :persona,
          subject: bootstrap.account,
          avatar_params: { moniker: "Conflict Avatar" },
          handle_params: { handle: "conflict" },
          owner_surface: "app",
          owner_collective_public_id: bootstrap.collective.public_id,
        )

        assert_not_predicate result, :success?
      end
    end
  end

  test "invalid avatar params leave no partial rows" do
    user = Client.create!(status_id: ClientStatus::ACTIVE, visibility_id: ClientVisibility::USER)
    bootstrap = BaseSelectorBootstrapAuthority.call(surface: :app, principal: user)
    bootstrap.avatar.current_avatar_persona_binding.revoke!(force: true)

    assert_no_difference -> {
      Avatar.count + Handle.count + AvatarPersonaBinding.count + AvatarAssignment.count
    } do
      result = AvatarProvisioning::Create.call(
        actor: user,
        subject_type: :persona,
        subject: bootstrap.account,
        avatar_params: { moniker: "" },
        handle_params: { handle: "invalid-avatar" },
        owner_surface: "app",
        owner_collective_public_id: bootstrap.collective.public_id,
      )

      assert_not_predicate result, :success?
    end
  end

  test "persona with an active binding gets a taken error and no partial rows" do
    user = Client.create!(status_id: ClientStatus::ACTIVE, visibility_id: ClientVisibility::USER)
    bootstrap = BaseSelectorBootstrapAuthority.call(surface: :app, principal: user)

    assert_no_difference -> {
      Avatar.count + Handle.count + AvatarPersonaBinding.count + AvatarOwnershipPeriod.count
    } do
      result = AvatarProvisioning::Create.call(
        actor: user,
        subject_type: :persona,
        subject: bootstrap.account,
        avatar_params: { moniker: "Second Avatar" },
        handle_params: { handle: "second" },
        owner_surface: "app",
        owner_collective_public_id: bootstrap.collective.public_id,
      )

      assert_not_predicate result, :success?
      assert result.errors.fetch(0).record.errors.of_kind?(:persona_id, :taken)
    end
  end

  test "new Avatar does not write transitional direct subject or owner columns" do
    user = Client.create!(status_id: ClientStatus::ACTIVE, visibility_id: ClientVisibility::USER)
    bootstrap = BaseSelectorBootstrapAuthority.call(surface: :app, principal: user)
    bootstrap.avatar.current_avatar_persona_binding.revoke!(force: true)

    result = AvatarProvisioning::Create.call(
      actor: user,
      subject_type: :persona,
      subject: bootstrap.account,
      avatar_params: { moniker: "Compat Avatar" },
      handle_params: { handle: "compatibility" },
      owner_surface: "app",
      owner_collective_public_id: bootstrap.collective.public_id,
    )

    assert_predicate result, :success?
    assert_nil result.avatar.client_id
    assert_nil result.avatar.owner_organization_id
    assert_nil result.avatar.representing_organization_id
    assert_equal bootstrap.account, result.avatar.current_persona
    assert_equal result.avatar, bootstrap.account.reload.current_avatar
  end

  test "member membership cannot create an Avatar even when caller supplies its owner ids" do
    user = Client.create!(status_id: ClientStatus::ACTIVE, visibility_id: ClientVisibility::USER)
    bootstrap = BaseSelectorBootstrapAuthority.call(surface: :app, principal: user)
    bootstrap.avatar.current_avatar_persona_binding.revoke!(force: true)
    membership = bootstrap.account.persona_memberships.find_by!(enterprise: bootstrap.collective)
    membership.update!(membership_kind_id: PersonaMembershipKind::MEMBER)

    assert_no_difference -> { Avatar.count + Handle.count + AvatarOwnershipPeriod.count } do
      error =
        assert_raises(StandardError) do
          AvatarProvisioning::Create.call(
            actor: user,
            subject_type: :persona,
            subject: bootstrap.account,
            avatar_params: { moniker: "Unauthorized" },
            handle_params: { handle: "unauthorized" },
            owner_surface: "app",
            owner_collective_public_id: bootstrap.collective.public_id,
          )
        end

      assert_equal "avatar.update permission required", error.message
    end
  end
end
