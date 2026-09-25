# typed: false
# frozen_string_literal: true

module GroupManagement
  class Create < ApplicationService
    AuthorizationDenied = AvatarOwnerMembershipLockService::AuthorizationDenied

    def initialize(account_surface:, account_public_id:, owner_surface:, owner_collective_public_id:,
                   actor:, subject_public_id:, name:, description: nil)
      super()
      @account_surface = account_surface.to_s
      @account_public_id = account_public_id.to_s
      @owner_surface = owner_surface.to_s
      @owner_collective_public_id = owner_collective_public_id.to_s
      @actor = actor
      @subject_public_id = subject_public_id.to_s
      @name = name
      @description = description
    end

    def call
      unless AvatarGroupOwnershipPeriod::OWNER_SURFACES.include?(owner_surface) &&
          account_surface == owner_surface && account_public_id.present? &&
          account_public_id == subject_public_id
        raise ArgumentError, "group account context is invalid"
      end
      raise ArgumentError, "owner_collective_public_id is required" if owner_collective_public_id.blank?

      AvatarOwnerMembershipLockService.call(
        actor: actor,
        surface: owner_surface,
        subject_public_id: subject_public_id,
        owner_collective_public_id: owner_collective_public_id,
        permission: "avatar.group.manage",
      ) do
        Avatar.transaction do
          group = AvatarGroup.create!(
            account_surface: account_surface,
            account_public_id: account_public_id,
            name: name,
            description: description,
            state: "active",
          )
          AvatarGroupOwnershipPeriod.create!(
            avatar_group: group,
            owner_surface: owner_surface,
            owner_collective_public_id: owner_collective_public_id,
            valid_from: Time.current,
          )
          group
        end
      end
    end

    private

    attr_reader :account_surface, :account_public_id, :owner_surface, :owner_collective_public_id,
                :actor, :subject_public_id, :name, :description
  end
end
