# typed: false
# frozen_string_literal: true

module AvatarOwnershipTransfers
  class CancelOperation < Operation
    def initialize(actor:, surface:, subject_public_id:, transfer_public_id:)
      super()
      @actor = actor
      @surface = surface.to_s
      @subject_public_id = subject_public_id.to_s
      @transfer_public_id = transfer_public_id.to_s
    end

    def call
      observed_transfer = find_transfer!(transfer_public_id)
      unless observed_transfer.from_owner_surface == surface
        raise Unauthorized, "transfer source surface does not match the authenticated surface"
      end

      expired = false
      result = nil
      with_authorized_owner_membership(
        surface: surface,
        actor: actor,
        subject_public_id: subject_public_id,
        owner_collective_public_id: observed_transfer.from_owner_collective_public_id,
        permission: "avatar.transfer.cancel",
      ) do
        Avatar.transaction do
          avatar = Avatar.lock.find(observed_transfer.avatar_id)
          transfer = AvatarOwnershipTransfer.lock.find(observed_transfer.id)
          assert_same_transfer!(transfer, observed_transfer)
          raise InvalidTransfer, "ownership transfer is already terminal" unless transfer.state == "pending"

          owner = current_owner!(avatar, lock: true)
          unless [owner.owner_surface, owner.owner_collective_public_id] ==
              [transfer.from_owner_surface, transfer.from_owner_collective_public_id]
            raise InvalidTransfer, "Avatar owner changed after transfer request"
          end

          cancelled_at = Time.current
          if transfer.expires_at <= cancelled_at
            transfer.update!(state: "expired", expired_at: cancelled_at)
            expired = true
            next
          end

          transfer.update!(
            state: "cancelled",
            cancelled_at: cancelled_at,
            cancel_actor_surface: surface,
            cancel_actor_public_id: subject_public_id,
          )
          result = transfer
        end
      end
      raise Expired, "ownership transfer expired" if expired

      result
    end

    private

    attr_reader :actor, :surface, :subject_public_id, :transfer_public_id

    def assert_same_transfer!(locked, observed)
      attributes = %w(
        public_id avatar_id from_owner_surface from_owner_collective_public_id
        to_owner_surface to_owner_collective_public_id
      )
      return if attributes.all? { |attribute| locked.public_send(attribute) == observed.public_send(attribute) }

      raise InvalidTransfer, "ownership transfer identity changed"
    end
  end
end
