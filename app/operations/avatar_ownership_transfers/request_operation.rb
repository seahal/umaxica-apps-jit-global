# typed: false
# frozen_string_literal: true

module AvatarOwnershipTransfers
  class RequestOperation < Operation
    VALID_FOR = 5.days

    def initialize(actor:, surface:, subject_public_id:, avatar_public_id:, target_surface:,
                   target_collective_public_id:, step_up_token: nil, step_up_requirement: nil)
      super()
      @actor = actor
      @surface = surface.to_s
      @subject_public_id = subject_public_id.to_s
      @avatar_public_id = avatar_public_id.to_s
      @target_surface = target_surface.to_s
      @target_collective_public_id = target_collective_public_id.to_s
      @step_up_token = step_up_token
      @step_up_requirement = step_up_requirement
    end

    def call
      validate_step_up_context!(
        actor: actor, surface: surface, scope: "avatar_transfer_request",
        token: step_up_token, requirement: step_up_requirement,
      )
      reject_legacy_transfer_after_cutover!
      validate_target!
      avatar = find_avatar!(avatar_public_id)
      observed_owner = current_owner!(avatar)
      unless observed_owner.owner_surface == surface
        raise Unauthorized, "selected actor is outside the Avatar's current owner surface"
      end

      result = nil
      with_authorized_owner_membership(
        surface: surface,
        actor: actor,
        subject_public_id: subject_public_id,
        owner_collective_public_id: observed_owner.owner_collective_public_id,
        permission: "avatar.transfer.request",
      ) do
        result = create_transfer_request!(avatar:, observed_owner:)
      end
      result
    end

    private

    attr_reader :actor, :surface, :subject_public_id, :avatar_public_id,
                :target_surface, :target_collective_public_id, :step_up_token, :step_up_requirement

    def validate_target!
      raise InvalidTransfer, "unsupported target surface" unless OWNER_DATA.key?(target_surface)
      raise InvalidTransfer, "target collective public id is required" if target_collective_public_id.blank?
      return if collective_exists?(surface: target_surface, public_id: target_collective_public_id)

      raise InvalidTransfer, "target collective not found"
    end

    def reject_legacy_transfer_after_cutover!
      return unless AvatarOwnershipCutover.established?

      raise InvalidTransfer, "legacy Avatar transfer operations are unavailable after cutover"
    end

    def assert_owner_unchanged!(current, observed)
      return if [current.owner_surface, current.owner_collective_public_id] ==
        [observed.owner_surface, observed.owner_collective_public_id]

      raise InvalidTransfer, "Avatar ownership changed while the transfer request was starting"
    end

    def create_transfer_request!(avatar:, observed_owner:)
      Avatar.transaction do
        locked_avatar = Avatar.lock.find(avatar.id)
        assert_eligible_avatar!(locked_avatar)
        owner = current_owner!(locked_avatar, lock: true)
        assert_owner_unchanged!(owner, observed_owner)
        if [owner.owner_surface, owner.owner_collective_public_id] ==
            [target_surface, target_collective_public_id]
          raise InvalidTransfer, "Avatar is already owned by the target collective"
        end

        now = Time.current
        expire_stale_pending!(locked_avatar, now: now)
        raise InvalidTransfer, "Avatar already has a pending ownership transfer" if
          AvatarOwnershipTransfer.pending.where(avatar_id: locked_avatar.id).lock.exists?

        transfer = AvatarOwnershipTransfer.create!(
          avatar: locked_avatar,
          from_owner_surface: owner.owner_surface,
          from_owner_collective_public_id: owner.owner_collective_public_id,
          to_owner_surface: target_surface,
          to_owner_collective_public_id: target_collective_public_id,
          state: "pending",
          requested_at: now,
          expires_at: now + VALID_FOR,
          request_actor_surface: surface,
          request_actor_public_id: subject_public_id,
        )
        consume_step_up!(step_up_token, step_up_requirement)
        transfer
      end
    end

    def expire_stale_pending!(avatar, now:)
      pending = AvatarOwnershipTransfer.pending.where(avatar_id: avatar.id).lock.first
      return unless pending && pending.expires_at <= now

      pending.update!(state: "expired", expired_at: now)
    end
  end
end
