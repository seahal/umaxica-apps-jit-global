# typed: false
# frozen_string_literal: true

require "test_helper"
require_relative "../support/avatar_test_factory"

class AvatarConcreteOwnershipPeriodTest < ActiveSupport::TestCase
  self.use_transactional_tests = false
  self.fixture_table_names = []

  test "an enterprise period stores a concrete organization reference" do
    AvatarRecord.transaction do
      avatar = AvatarTestFactory.create!(
        moniker: "Enterprise owner",
        capability: AvatarCapability.find_or_create_by!(id: AvatarCapability::NORMAL),
        active_handle: Handle.create!(
          handle: "concrete-enterprise-#{SecureRandom.hex(4)}",
          cooldown_until: Time.current,
        ),
      )
      period = AvatarEnterpriseOwnershipPeriod.create!(
        avatar: avatar,
        enterprise_public_id: "enterprise_concrete_1",
        valid_from: avatar.created_at,
      )

      assert_equal avatar.id, period.avatar_id
      assert_equal "enterprise_concrete_1", period.enterprise_public_id
      assert_predicate period, :current?

      raise ActiveRecord::Rollback
    end
  end

  test "cross-family ownership periods cannot overlap for one avatar" do
    error = nil

    AvatarRecord.transaction do
      avatar = AvatarTestFactory.create!(
        moniker: "Cross family",
        capability: AvatarCapability.find_or_create_by!(id: AvatarCapability::NORMAL),
        active_handle: Handle.create!(handle: "concrete-overlap-#{SecureRandom.hex(4)}", cooldown_until: Time.current),
      )
      first_end = avatar.created_at + 1.hour
      AvatarEnterpriseOwnershipPeriod.create!(
        avatar: avatar,
        enterprise_public_id: "enterprise_overlap_1",
        valid_from: avatar.created_at,
        valid_to: first_end,
      )
      AvatarBureauOwnershipPeriod.create!(
        avatar: avatar,
        bureau_public_id: "bureau_overlap_1",
        valid_from: avatar.created_at + 30.minutes,
      )

      error =
        assert_raises(ActiveRecord::StatementInvalid) do
          AvatarRecord.connection.execute("SET CONSTRAINTS ALL IMMEDIATE")
        end
      raise ActiveRecord::Rollback
    end

    assert_match(/overlap|ownership/i, error.message)
  end

  test "an adjacent enterprise to bureau ownership chain is accepted" do
    AvatarRecord.transaction do
      avatar = AvatarTestFactory.create!(
        moniker: "Adjacent owners",
        capability: AvatarCapability.find_or_create_by!(id: AvatarCapability::NORMAL),
        active_handle: Handle.create!(handle: "concrete-adjacent-#{SecureRandom.hex(4)}", cooldown_until: Time.current),
      )
      transfer_at = avatar.created_at + 1.hour
      enterprise = AvatarEnterpriseOwnershipPeriod.create!(
        avatar: avatar,
        enterprise_public_id: "enterprise_adjacent_1",
        valid_from: avatar.created_at,
        valid_to: transfer_at,
      )
      bureau = AvatarBureauOwnershipPeriod.create!(
        avatar: avatar,
        bureau_public_id: "bureau_adjacent_1",
        valid_from: transfer_at,
      )

      AvatarRecord.connection.execute("SET CONSTRAINTS ALL IMMEDIATE")

      assert_equal transfer_at, enterprise.valid_to
      assert_predicate bureau, :current?

      raise ActiveRecord::Rollback
    end
  end

  test "direct SQL cannot change the concrete owner identity" do
    error = nil

    AvatarRecord.transaction do
      avatar = AvatarTestFactory.create!(
        moniker: "Immutable owner",
        capability: AvatarCapability.find_or_create_by!(id: AvatarCapability::NORMAL),
        active_handle: Handle.create!(
          handle: "concrete-immutable-#{SecureRandom.hex(4)}",
          cooldown_until: Time.current,
        ),
      )
      period = AvatarEnterpriseOwnershipPeriod.create!(
        avatar: avatar,
        enterprise_public_id: "enterprise_immutable_1",
        valid_from: avatar.created_at,
      )

      error =
        assert_raises(ActiveRecord::StatementInvalid) do
          AvatarRecord.connection.execute(
            "UPDATE avatar_enterprise_ownership_periods " \
            "SET enterprise_public_id = 'enterprise_immutable_2' WHERE id = #{period.id}",
          )
        end
      raise ActiveRecord::Rollback
    end

    assert_match(/immutable|ownership/i, error.message)
  end

  test "direct SQL cannot delete concrete ownership history" do
    error = nil

    AvatarRecord.transaction do
      avatar = AvatarTestFactory.create!(
        moniker: "Delete history",
        capability: AvatarCapability.find_or_create_by!(id: AvatarCapability::NORMAL),
        active_handle: Handle.create!(handle: "concrete-delete-#{SecureRandom.hex(4)}", cooldown_until: Time.current),
      )
      period = AvatarEnterpriseOwnershipPeriod.create!(
        avatar: avatar,
        enterprise_public_id: "enterprise_delete_1",
        valid_from: avatar.created_at,
      )

      error =
        assert_raises(ActiveRecord::StatementInvalid) do
          AvatarRecord.connection.execute(
            "DELETE FROM avatar_enterprise_ownership_periods WHERE id = #{period.id}",
          )
        end
      raise ActiveRecord::Rollback
    end

    assert_match(/immutable|history/i, error.message)
  end

  test "direct SQL cannot truncate concrete ownership history" do
    error = nil

    AvatarRecord.transaction do
      avatar = AvatarTestFactory.create!(
        moniker: "Truncate history",
        capability: AvatarCapability.find_or_create_by!(id: AvatarCapability::NORMAL),
        active_handle: Handle.create!(handle: "concrete-truncate-#{SecureRandom.hex(4)}", cooldown_until: Time.current),
      )
      AvatarEnterpriseOwnershipPeriod.create!(
        avatar: avatar,
        enterprise_public_id: "enterprise_truncate_1",
        valid_from: avatar.created_at,
      )

      error =
        assert_raises(ActiveRecord::StatementInvalid) do
          AvatarRecord.connection.execute("TRUNCATE avatar_enterprise_ownership_periods")
        end
      raise ActiveRecord::Rollback
    end

    assert_match(/truncate|history/i, error.message)
  end

  test "a transfer may close the current period when it creates the adjacent next period" do
    AvatarRecord.transaction do
      avatar = AvatarTestFactory.create!(
        moniker: "Close current",
        capability: AvatarCapability.find_or_create_by!(id: AvatarCapability::NORMAL),
        active_handle: Handle.create!(handle: "concrete-close-#{SecureRandom.hex(4)}", cooldown_until: Time.current),
      )
      period = AvatarEnterpriseOwnershipPeriod.create!(
        avatar: avatar,
        enterprise_public_id: "enterprise_close_1",
        valid_from: avatar.created_at,
      )
      transfer_at = avatar.created_at + 1.hour

      AvatarRecord.connection.execute(
        "UPDATE avatar_enterprise_ownership_periods " \
        "SET valid_to = '#{transfer_at.iso8601(6)}' WHERE id = #{period.id}",
      )
      AvatarBureauOwnershipPeriod.create!(
        avatar: avatar,
        bureau_public_id: "bureau_close_1",
        valid_from: transfer_at,
      )
      AvatarRecord.connection.execute("SET CONSTRAINTS ALL IMMEDIATE")

      assert_equal transfer_at, period.reload.valid_to
      raise ActiveRecord::Rollback
    end
  end

  test "a transfer cannot change the owner while closing the current period" do
    error = nil

    AvatarRecord.transaction do
      avatar = AvatarTestFactory.create!(
        moniker: "Owner close",
        capability: AvatarCapability.find_or_create_by!(id: AvatarCapability::NORMAL),
        active_handle: Handle.create!(
          handle: "concrete-owner-close-#{SecureRandom.hex(4)}",
          cooldown_until: Time.current,
        ),
      )
      period = AvatarEnterpriseOwnershipPeriod.create!(
        avatar: avatar,
        enterprise_public_id: "enterprise_owner_close_1",
        valid_from: avatar.created_at,
      )
      transfer_at = avatar.created_at + 1.hour

      error =
        assert_raises(ActiveRecord::StatementInvalid) do
          AvatarRecord.connection.execute(
            "UPDATE avatar_enterprise_ownership_periods " \
            "SET enterprise_public_id = 'enterprise_owner_close_2', " \
            "valid_to = '#{transfer_at.iso8601(6)}' WHERE id = #{period.id}",
          )
        end
      raise ActiveRecord::Rollback
    end

    assert_match(/immutable|ownership/i, error.message)
  end
end
