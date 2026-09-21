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

  test "validates id is numeric" do
    # With bigint ID, length validation is irrelevant
    # Test that record validation works with all required fields
    AvatarOwnershipStatus.find_or_create_by!(id: 1)
    avatar = Avatar.create!(
      capability: AvatarCapability.find_or_create_by!(id: AvatarCapability::NORMAL),
      active_handle: Handle.create!(handle: "test-#{SecureRandom.hex(4)}", cooldown_until: Time.current),
      moniker: "Test",
    )
    record = AvatarOwnershipPeriod.new(
      id: 99,
      avatar: avatar,
      owner_organization_id: "org_123",
      valid_from: Time.current,
    )

    assert_predicate record, :valid?
    assert_kind_of Integer, record.id
  end
end
