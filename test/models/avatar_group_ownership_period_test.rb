# typed: false
# frozen_string_literal: true

require "test_helper"

class AvatarGroupOwnershipPeriodTest < ActiveSupport::TestCase
  test "accepts app and org ownership and rejects com" do
    group = AvatarGroup.create!(
      account_surface: "com",
      account_public_id: "account-public-id",
      name: "Independently managed group",
      state: "active",
    )

    app_owner = AvatarGroupOwnershipPeriod.new(
      avatar_group: group,
      owner_surface: "app",
      owner_collective_public_id: "enterprise-public-id",
      valid_from: Time.current,
    )
    org_owner = AvatarGroupOwnershipPeriod.new(
      avatar_group: group,
      owner_surface: "org",
      owner_collective_public_id: "bureau-public-id",
      valid_from: Time.current,
    )
    com_owner = AvatarGroupOwnershipPeriod.new(
      avatar_group: group,
      owner_surface: "com",
      owner_collective_public_id: "company-public-id",
      valid_from: Time.current,
    )

    assert_predicate app_owner, :valid?
    assert_predicate org_owner, :valid?
    assert_not com_owner.valid?
    assert com_owner.errors.of_kind?(:owner_surface, :inclusion)
  end

  test "requires a collective public id and keeps one current owner period" do
    group = AvatarGroup.create!(
      account_surface: "org",
      account_public_id: "account-public-id",
      name: "Owned group",
      state: "active",
    )
    period = AvatarGroupOwnershipPeriod.create!(
      avatar_group: group,
      owner_surface: "org",
      owner_collective_public_id: "bureau-public-id",
      valid_from: Time.current,
    )
    duplicate = AvatarGroupOwnershipPeriod.new(
      avatar_group: group,
      owner_surface: "org",
      owner_collective_public_id: "another-bureau-public-id",
      valid_from: Time.current,
    )
    missing_collective = AvatarGroupOwnershipPeriod.new(
      avatar_group: AvatarGroup.new(
        account_surface: "app",
        account_public_id: "account-public-id",
        name: "Missing owner",
        state: "active",
      ),
      owner_surface: "app",
      valid_from: Time.current,
    )

    assert_not duplicate.valid?
    assert duplicate.errors.of_kind?(:avatar_group_id, :taken)
    assert_not missing_collective.valid?
    assert missing_collective.errors.of_kind?(:owner_collective_public_id, :blank)
    assert_predicate period.reload, :current?
  end
end
