# frozen_string_literal: true

require "test_helper"
require_relative "../support/avatar_test_factory"

class AvatarTransferDetailUniquenessTest < ActiveSupport::TestCase
  DIRECTIONS = [
    [AvatarEnterpriseToEnterpriseTransferDetail, AvatarEnterpriseOwnershipPeriod, :enterprise_public_id,
     :source_enterprise_public_id, :destination_enterprise_public_id, "enterprise_to_enterprise",],
    [AvatarEnterpriseToBureauTransferDetail, AvatarEnterpriseOwnershipPeriod, :enterprise_public_id,
     :source_enterprise_public_id, :destination_bureau_public_id, "enterprise_to_bureau",],
    [AvatarBureauToEnterpriseTransferDetail, AvatarBureauOwnershipPeriod, :bureau_public_id,
     :source_bureau_public_id, :destination_enterprise_public_id, "bureau_to_enterprise",],
    [AvatarBureauToBureauTransferDetail, AvatarBureauOwnershipPeriod, :bureau_public_id,
     :source_bureau_public_id, :destination_bureau_public_id, "bureau_to_bureau",],
  ].freeze

  DIRECTIONS.each do |detail_class, period_class, owner_key, source_key, destination_key, kind|
    test "#{detail_class.name} keeps DB enforcement and rejects a second detail before creation" do
      avatar = AvatarTestFactory.create!(
        moniker: "Transfer detail", create_concrete_owner: false,
        active_handle: AvatarTestFactory.create_handle!, capability_id: AvatarCapability::NORMAL,
        lifecycle_state: AvatarLifecycleState.find_by!(key: "active"),
      )
      period = period_class.create!(:avatar => avatar, owner_key => "source", :valid_from => avatar.created_at)
      reservation = AvatarOwnershipTransfers::ReservationCreator.new(
        avatar: avatar, operation_kind: kind, idempotency_key: SecureRandom.uuid,
        request_fingerprint: Digest::SHA256.hexdigest("detail"), source_collective_public_id: "source",
        destination_collective_public_id: "destination", request_actor_public_id: "actor",
        source_ownership_period_id: period.id,
      ).call
      detail = detail_class.find_by!(transfer_reservation_id: reservation.id)
      attributes = { :transfer_reservation => reservation,
                     :source_ownership_period => period,
                     source_key => "source",
                     destination_key => "destination",
                     :request_actor_public_id => "actor", }

      assert_equal reservation.id, detail.reload.transfer_reservation_id
      assert_raises(ActiveRecord::RecordNotUnique) do
        detail_class.transaction(requires_new: true) { detail_class.new(attributes).save!(validate: false) }
      end
      duplicate = detail_class.new(attributes)

      assert_not duplicate.valid?
      assert duplicate.errors.of_kind?(:transfer_reservation_id, :taken)
      assert_raises(ActiveRecord::RecordInvalid) { duplicate.save! }
      replay = AvatarOwnershipTransfers::ReservationCreator.new(
        avatar: avatar, operation_kind: kind, idempotency_key: reservation.idempotency_key,
        request_fingerprint: reservation.request_fingerprint, source_collective_public_id: "source",
        destination_collective_public_id: "destination", request_actor_public_id: "actor",
        source_ownership_period_id: period.id,
      ).call

      assert_equal reservation.id, replay.id
      assert_equal 1, detail_class.where(transfer_reservation_id: reservation.id).count
    end
  end
end
