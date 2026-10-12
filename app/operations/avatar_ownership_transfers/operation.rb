# typed: false
# frozen_string_literal: true

module AvatarOwnershipTransfers
  class Operation < ApplicationService
    OWNER_DATA = {
      "app" => { collective: Enterprise },
      "org" => { collective: Bureau },
    }.freeze

    private

    def with_authorized_owner_membership(surface:, actor:, subject_public_id:, owner_collective_public_id:, permission:)
      AvatarOwnerMembershipLockService.call(
        actor: actor,
        surface: surface,
        subject_public_id: subject_public_id,
        owner_collective_public_id: owner_collective_public_id,
        permission: permission,
      ) { yield }
    end

    def collective_exists?(surface:, public_id:)
      config = OWNER_DATA[surface.to_s]
      config&.fetch(:collective)&.exists?(public_id: public_id)
    end

    def find_avatar!(public_id)
      Avatar.find_by(public_id: public_id) || raise(ActiveRecord::RecordNotFound, "Avatar not found")
    end

    def find_transfer!(public_id)
      AvatarOwnershipTransfer.find_by(public_id: public_id) ||
        raise(ActiveRecord::RecordNotFound, "Avatar ownership transfer not found")
    end

    def current_owner!(avatar, lock: false)
      AvatarOwnershipPeriodSource.current_for(avatar, lock: lock)
    rescue AvatarOwnershipPeriodSource::InvalidState => e
      raise InvalidTransfer, e.message
    end

    def concrete_current_owner!(avatar, lock: false)
      return AvatarOwnershipPeriodSource.current_for(avatar, lock: lock) unless
        AvatarOwnershipPeriodSource.legacy?

      relations = [
        AvatarEnterpriseOwnershipPeriod.current.where(avatar_id: avatar.id),
        AvatarBureauOwnershipPeriod.current.where(avatar_id: avatar.id),
      ]
      periods = relations.flat_map { |relation| (lock ? relation.lock : relation).to_a }
      return periods.first if periods.one?

      raise InvalidTransfer, "Avatar has an invalid concrete ownership state"
    end

    def concrete_period_class_for(surface)
      AvatarOwnershipPeriodSource.concrete_period_class_for(surface)
    rescue AvatarOwnershipPeriodSource::InvalidState => e
      raise InvalidTransfer, e.message
    end

    def assert_eligible_avatar!(avatar)
      return if avatar.lifecycle_state&.key == "active" && avatar.accessible?

      raise InvalidTransfer, "Avatar is not eligible for ownership transfer"
    end

    def lock_group_rows_before_avatar!(avatar_id)
      locked_ids = Set.new

      loop do
        group_ids = GroupAvatarMembership.active
          .where(avatar_id: avatar_id)
          .distinct
          .order(:avatar_group_id)
          .pluck(:avatar_group_id)
        new_ids = group_ids.reject { |id| locked_ids.include?(id) }
        AvatarGroup.where(id: new_ids).order(:id).lock.load if new_ids.any?
        locked_ids |= new_ids

        remaining_ids =
          GroupAvatarMembership.active
            .where(avatar_id: avatar_id)
            .distinct
            .pluck(:avatar_group_id)
            .reject { |id| locked_ids.include?(id) }
        break if remaining_ids.empty?
      end
    end

    def remove_group_memberships_with_different_owner!(avatar:, owner_surface:, owner_collective_public_id:, at:)
      memberships = GroupAvatarMembership.active
        .where(avatar_id: avatar.id)
        .order(:avatar_group_id, :id)
        .lock
        .to_a
      group_owners = AvatarGroupOwnershipPeriodSource.current
        .where(avatar_group_id: memberships.map(&:avatar_group_id))
        .index_by(&:avatar_group_id)

      memberships.each do |membership|
        group_owner = group_owners[membership.avatar_group_id]
        next if group_owner&.owner_surface == owner_surface &&
          group_owner.owner_collective_public_id == owner_collective_public_id

        membership.update!(state: "removed", removed_at: at)
      end
    end
  end
end
