# frozen_string_literal: true

require "test_helper"
require_relative "../support/avatar_test_factory"

class AvatarOwnershipTransitionInventoryQueryTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  setup do
    @capability = AvatarCapability.find_or_create_by!(id: AvatarCapability::NORMAL)
  end

  def active_handle(prefix)
    Handle.create!(handle: "#{prefix}-#{SecureRandom.hex(4)}", cooldown_until: Time.current)
  end

  test "classifies a legacy and concrete ownership chain with matching facts as ready" do
    client = Client.create!(
      security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE,
      visibility_id: ClientVisibility::USER,
    )
    avatar = BaseSelectorBootstrapAuthority.call(surface: :app, principal: client).avatar
    legacy = avatar.avatar_ownership_periods.order(:id).last
    concrete = avatar.enterprise_ownership_periods.order(:id).last
    legacy.update!(valid_from: concrete.valid_from)

    result = AvatarOwnershipTransitionInventoryQuery.call(avatar_ids: [avatar.id])
    detail = result.details.fetch(0)

    assert_equal "ready", detail.fetch(:classification)
    assert_equal avatar.id, detail.fetch(:avatar_id)
    assert_equal "app", detail.fetch(:legacy_owner_surface)
    assert_equal detail.fetch(:legacy_owner_collective_public_id), detail.fetch(:concrete_owner_public_id)
    assert_predicate result, :ready?
    assert_equal({ "ready" => 1 }, result.summary.fetch(:classifications))
  end

  test "classifies an avatar that already has only concrete ownership as concrete_only" do
    avatar = AvatarTestFactory.create!(
      moniker: "Concrete only",
      create_concrete_owner: true,
      capability: @capability,
      active_handle: active_handle("inventory-concrete"),
    )

    result = AvatarOwnershipTransitionInventoryQuery.call(avatar_ids: [avatar.id])
    detail = result.details.fetch(0)

    assert_equal "concrete_only", detail.fetch(:classification)
    assert_nil detail.fetch(:legacy_owner_surface)
    assert_equal "app", detail.fetch(:concrete_owner_surface)
    assert_predicate result, :ready?
  end

  test "is read-only and rejects an unbounded or invalid avatar selection" do
    avatar = AvatarTestFactory.create!(
      moniker: "Inventory read",
      create_concrete_owner: true,
      capability: @capability,
      active_handle: active_handle("inventory-read-only"),
    )
    before = [avatar.reload.attributes, AvatarEnterpriseOwnershipPeriod.where(avatar_id: avatar.id).count]

    result = AvatarOwnershipTransitionInventoryQuery.call(avatar_ids: [avatar.id])

    assert_equal before, [avatar.reload.attributes, AvatarEnterpriseOwnershipPeriod.where(avatar_id: avatar.id).count]
    assert_raises(ArgumentError) { AvatarOwnershipTransitionInventoryQuery.call(avatar_ids: [nil]) }
    assert_raises(ArgumentError) {
      AvatarOwnershipTransitionInventoryQuery.call(
        avatar_ids: Array.new(501) {
          avatar.id
        },
      )
    }
    assert_predicate result.details, :any?
  end
end
