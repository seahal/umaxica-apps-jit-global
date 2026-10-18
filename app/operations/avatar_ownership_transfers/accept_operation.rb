# typed: false
# frozen_string_literal: true

module AvatarOwnershipTransfers
  class AcceptOperation < Operation
    def initialize(actor:, surface:, subject_public_id:, transfer_public_id:)
      super()
      @actor = actor
      @surface = surface.to_s
      @subject_public_id = subject_public_id.to_s
      @transfer_public_id = transfer_public_id.to_s
    end

    def call
      reject_legacy_transfer_after_cutover!
      observed_transfer = find_transfer!(transfer_public_id)
      unless observed_transfer.to_owner_surface == surface
        raise Unauthorized, "transfer target surface does not match the authenticated surface"
      end

      expired = false
      result = nil
      with_authorized_owner_membership(
        surface: surface,
        actor: actor,
        subject_public_id: subject_public_id,
        owner_collective_public_id: observed_transfer.to_owner_collective_public_id,
        permission: "avatar.transfer.accept",
      ) do
        Avatar.transaction do
          lock_group_rows_before_avatar!(observed_transfer.avatar_id)
          avatar = Avatar.lock.find(observed_transfer.avatar_id)
          assert_eligible_avatar!(avatar)
          transfer = AvatarOwnershipTransfer.lock.find(observed_transfer.id)
          assert_same_transfer!(transfer, observed_transfer)

          unless transfer.state == "pending"
            raise InvalidTransfer, "ownership transfer is already terminal"
          end

          accepted_at = Time.current
          if transfer.expires_at <= accepted_at
            transfer.update!(state: "expired", expired_at: accepted_at)
            expired = true
            next
          end

          accept_transfer!(avatar, transfer, accepted_at)
          result = transfer
        end
      end
      raise Expired, "ownership transfer expired" if expired

      result
    end

    private

    attr_reader :actor, :surface, :subject_public_id, :transfer_public_id

    def accept_transfer!(avatar, transfer, accepted_at)
      assert_transfer_owners!(avatar, transfer)

      active = AvatarOwnershipStatus.find_or_create_by!(id: AvatarOwnershipStatus::ACTIVE)
      inactive = AvatarOwnershipStatus.find_or_create_by!(id: AvatarOwnershipStatus::INACTIVE)
      close_legacy_period!(avatar, accepted_at, inactive)
      open_legacy_period!(avatar, transfer, accepted_at, active)
      close_concrete_period!(avatar, accepted_at)
      open_concrete_period!(avatar, transfer, accepted_at)

      remove_group_memberships_with_different_owner!(
        avatar: avatar,
        owner_surface: transfer.to_owner_surface,
        owner_collective_public_id: transfer.to_owner_collective_public_id,
        at: accepted_at,
      )

      transfer.update!(
        state: "accepted",
        accepted_at: accepted_at,
        accept_actor_surface: surface,
        accept_actor_public_id: subject_public_id,
      )
    end

    def assert_transfer_owners!(avatar, transfer)
      owner = current_owner!(avatar, lock: true)
      unless [owner.owner_surface, owner.owner_collective_public_id] ==
          [transfer.from_owner_surface, transfer.from_owner_collective_public_id]
        raise InvalidTransfer, "Avatar owner changed after transfer request"
      end

      concrete_owner = concrete_current_owner!(avatar, lock: true)
      expected_class = concrete_period_class_for(transfer.from_owner_surface)
      expected_id = transfer.from_owner_collective_public_id
      owner_prefix = (transfer.from_owner_surface == "app") ? "enterprise" : "bureau"
      concrete_id = concrete_owner.public_send("#{owner_prefix}_public_id")
      unless concrete_owner.class == expected_class && concrete_id == expected_id
        raise InvalidTransfer, "Avatar concrete owner changed after transfer request"
      end
      return if transfer.to_owner_surface == surface && transfer.to_owner_collective_public_id.present?

      raise InvalidTransfer, "transfer target owner changed"
    end

    def close_legacy_period!(avatar, accepted_at, inactive)
      current_owner!(avatar, lock: true).update!(valid_to: accepted_at, avatar_ownership_status: inactive)
    end

    def open_legacy_period!(avatar, transfer, accepted_at, active)
      AvatarOwnershipPeriod.create!(
        avatar: avatar,
        owner_organization_id: transfer.to_owner_collective_public_id,
        owner_surface: transfer.to_owner_surface,
        owner_collective_public_id: transfer.to_owner_collective_public_id,
        avatar_ownership_status: active,
        valid_from: accepted_at,
      )
    end

    def close_concrete_period!(avatar, accepted_at)
      concrete_current_owner!(avatar, lock: true).update!(valid_to: accepted_at)
    end

    def open_concrete_period!(avatar, transfer, accepted_at)
      attributes = {
        avatar: avatar,
        valid_from: accepted_at,
        transferred_by_actor_public_id: transfer.accept_actor_public_id || transfer.request_actor_public_id,
      }
      attributes[(transfer.to_owner_surface == "app") ? :enterprise_public_id : :bureau_public_id] =
        transfer.to_owner_collective_public_id
      concrete_period_class_for(transfer.to_owner_surface).create!(**attributes)
    end

    def assert_same_transfer!(locked, observed)
      attributes = %w(
        public_id avatar_id from_owner_surface from_owner_collective_public_id
        to_owner_surface to_owner_collective_public_id
      )
      return if attributes.all? { |attribute| locked.public_send(attribute) == observed.public_send(attribute) }

      raise InvalidTransfer, "ownership transfer identity changed"
    end

    def reject_legacy_transfer_after_cutover!
      return unless AvatarOwnershipCutover.established?

      raise InvalidTransfer, "legacy Avatar transfer operations are unavailable after cutover"
    end
  end
end
