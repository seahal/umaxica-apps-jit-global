# typed: false
# frozen_string_literal: true

module AvatarOwnershipTransfers
  class CancelOperation < Operation
    def initialize(actor:, surface:, subject_public_id:, transfer_public_id:, step_up_token: nil,
                   step_up_evidence: nil)
      super()
      @actor = actor
      @surface = surface.to_s
      @subject_public_id = subject_public_id.to_s
      @transfer_public_id = transfer_public_id.to_s
      @step_up_token = step_up_token
      @step_up_evidence = step_up_evidence
    end

    def call
      validate_step_up_context!(actor: actor, token: step_up_token, evidence: step_up_evidence)
      reject_legacy_transfer_after_cutover!
      observed_transfer = find_transfer!(transfer_public_id)
      raise Unauthorized, "transfer source surface does not match the authenticated surface" unless
        observed_transfer.from_owner_surface == surface

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
          verify_step_up!(actor:, token: step_up_token, evidence: step_up_evidence)
          result = transfer
        end
      end
      raise Expired, "ownership transfer expired" if expired

      result
    end

    private

    attr_reader :actor, :surface, :subject_public_id, :transfer_public_id, :step_up_token, :step_up_evidence

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
