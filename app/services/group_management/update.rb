# typed: false
# frozen_string_literal: true

module GroupManagement
  class Update < ApplicationService
    AuthorizationDenied = AvatarOwnerMembershipLockService::AuthorizationDenied

    def initialize(group:, attributes:, actor:, surface:, subject_public_id:, account_public_id:)
      super()
      @group = group
      @attributes = attributes.to_h.slice(:name, :description)
      @actor = actor
      @surface = surface.to_s
      @subject_public_id = subject_public_id.to_s
      @account_public_id = account_public_id.to_s
    end

    def call
      observed_owner = AvatarGroupOwnershipPeriod.current.find_by!(avatar_group_id: group.id)
      unless observed_owner.owner_surface == surface
        raise AuthorizationDenied, "group owner surface does not match actor surface"
      end

      AvatarOwnerMembershipLockService.call(
        actor: actor,
        surface: surface,
        subject_public_id: subject_public_id,
        owner_collective_public_id: observed_owner.owner_collective_public_id,
        permission: "avatar.group.manage",
      ) do
        Avatar.transaction do
          locked_group = AvatarGroup.lock.find(group.id)
          authorize!(locked_group, observed_owner)
          raise ArgumentError, "group is archived" unless locked_group.active?

          locked_group.update!(attributes)
          locked_group
        end
      end
    end

    private

    attr_reader :group, :attributes, :actor, :surface, :subject_public_id, :account_public_id

    def authorize!(locked_group, observed_owner)
      unless %w(app org).include?(surface) && account_public_id.present? &&
          account_public_id == subject_public_id && locked_group.account_surface == surface &&
          locked_group.account_public_id == account_public_id
        raise AuthorizationDenied, "group account scope does not match actor context"
      end

      owner = AvatarGroupOwnershipPeriod.current.lock.find_by(avatar_group_id: locked_group.id)
      raise AuthorizationDenied, "current group owner missing" unless owner && owner.owner_surface == surface
      return if [owner.owner_surface, owner.owner_collective_public_id] ==
        [observed_owner.owner_surface, observed_owner.owner_collective_public_id]

      raise AuthorizationDenied, "current group owner changed while updating"
    end
  end
end
