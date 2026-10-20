# frozen_string_literal: true

require "test_helper"
require_relative "../support/avatar_test_factory"

class AvatarCurrentPeriodUniquenessTest < ActiveSupport::TestCase
  PERIODS = [
    [AvatarEnterpriseOwnershipPeriod, :enterprise_public_id],
    [AvatarBureauOwnershipPeriod, :bureau_public_id],
  ].freeze

  PERIODS.each do |period_class, owner_key|
    test "#{period_class.name} preflights precisely the open infinity period" do
      avatar = AvatarTestFactory.create!(
        moniker: "Period unique", create_concrete_owner: false,
        active_handle: AvatarTestFactory.create_handle!, capability_id: AvatarCapability::NORMAL,
        lifecycle_state: AvatarLifecycleState.find_by!(key: "active"),
      )
      attributes = { :avatar => avatar, owner_key => "owner", :valid_from => avatar.created_at }
      period = period_class.create!(attributes)

      assert_predicate period, :current?
      assert_raises(ActiveRecord::RecordNotUnique) do
        period_class.transaction(requires_new: true) { period_class.new(attributes).save!(validate: false) }
      end
      duplicate = period_class.new(attributes)

      assert_not duplicate.valid?
      assert duplicate.errors.of_kind?(:avatar_id, :taken)
      assert_raises(ActiveRecord::RecordInvalid) { duplicate.save! }
      finite = period_class.new(attributes.merge(valid_to: avatar.created_at + 60))
      # Finite candidates do not participate in this index; temporal exclusion remains DB-owned.
      assert_predicate finite, :valid?
      future = period_class.new(attributes.merge(valid_from: avatar.created_at + 3600))

      assert_not future.valid?
      assert future.errors.of_kind?(:avatar_id, :taken)
    end
  end
end
