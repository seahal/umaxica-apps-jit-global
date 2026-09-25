# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: avatar_ownership_periods
# Database name: avatar
#
#  id                         :bigint           not null, primary key
#  valid_from                 :datetime         not null
#  valid_to                   :datetime         default(Infinity), not null
#  created_at                 :datetime         not null
#  updated_at                 :datetime         not null
#  avatar_id                  :bigint           not null
#  avatar_ownership_status_id :bigint
#  owner_organization_id      :string           not null
#  transferred_by_actor_id    :bigint
#
# Indexes
#
#  idx_avatar_ownership_periods_avatar_id_all_rows               (avatar_id)
#  index_avatar_ownership_periods_on_avatar_id                   (avatar_id) UNIQUE WHERE (valid_to = 'infinity'::timestamp with time zone)
#  index_avatar_ownership_periods_on_avatar_ownership_status_id  (avatar_ownership_status_id)
#  index_avatar_ownership_periods_on_owner_organization_id       (owner_organization_id) WHERE (valid_to = 'infinity'::timestamp with time zone)
#
# Foreign Keys
#
#  fk_rails_...  (avatar_id => avatars.id)
#  fk_rails_...  (avatar_ownership_status_id => avatar_ownership_statuses.id)
#

require "test_helper"
require_relative "../support/avatar_test_factory"

class AvatarOwnershipPeriodTest < ActiveSupport::TestCase
  test "has the approved all-rows avatar lookup index alongside the current-row unique index" do
    indexes = AvatarOwnershipPeriod.lease_connection.indexes(AvatarOwnershipPeriod.table_name)

    all_rows_index = indexes.find { |index| index.name == "idx_avatar_ownership_periods_avatar_id_all_rows" }
    current_row_index = indexes.find { |index| index.name == "index_avatar_ownership_periods_on_avatar_id" }

    assert_not_nil all_rows_index
    assert_equal ["avatar_id"], all_rows_index.columns
    assert_not all_rows_index.unique
    assert_nil all_rows_index.where
    assert_predicate all_rows_index, :valid

    assert_not_nil current_row_index
    assert_equal ["avatar_id"], current_row_index.columns
    assert_predicate current_row_index, :unique
    assert_match(/valid_to\s*=\s*'infinity'/, current_row_index.where)
  end

  test "validations" do
    period = AvatarOwnershipPeriod.new

    assert_not period.valid?
  end

  test "accepts app and org owner references independent of the legacy organization column" do
    AvatarOwnershipStatus.find_or_create_by!(id: AvatarOwnershipStatus::ACTIVE)
    avatar = AvatarTestFactory.create!(
      moniker: "Test",
      capability: AvatarCapability.find_or_create_by!(id: AvatarCapability::NORMAL),
      active_handle: Handle.create!(handle: "test-#{SecureRandom.hex(4)}", cooldown_until: Time.current),
    )
    record = AvatarOwnershipPeriod.new(
      id: 99,
      avatar: avatar,
      owner_organization_id: "org_123",
      owner_surface: "app",
      owner_collective_public_id: "collective_app_123",
      avatar_ownership_status_id: AvatarOwnershipStatus::ACTIVE,
      valid_from: Time.current,
    )

    assert_predicate record, :valid?
    assert_kind_of Integer, record.id

    record.owner_surface = "org"
    record.owner_collective_public_id = "collective_org_123"

    assert_predicate record, :valid?
  end

  test "rejects com ownership and a missing owner collective" do
    avatar = AvatarTestFactory.create!(
      moniker: "Owner boundary",
      capability: AvatarCapability.find_or_create_by!(id: AvatarCapability::NORMAL),
      active_handle: Handle.create!(handle: "owner-boundary-#{SecureRandom.hex(4)}", cooldown_until: Time.current),
    )
    period = AvatarOwnershipPeriod.new(
      avatar: avatar,
      owner_organization_id: "legacy-id",
      owner_surface: "com",
      owner_collective_public_id: "collective-id",
      avatar_ownership_status_id: AvatarOwnershipStatus::ACTIVE,
      valid_from: Time.current,
    )

    assert_not period.valid?
    assert period.errors.of_kind?(:owner_surface, :inclusion)

    period.owner_surface = "app"
    period.owner_collective_public_id = nil

    assert_not period.valid?
    assert period.errors.of_kind?(:owner_collective_public_id, :blank)
  end
end
