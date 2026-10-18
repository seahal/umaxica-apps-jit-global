# frozen_string_literal: true

module AvatarAssignmentAuthorityProtection
  extend ActiveSupport::Concern

  PROTECTED_ROLES = %w(owner administrator).freeze
  LAST_ROLE_ERROR_BY_ROLE = {
    "owner" => :last_avatar_owner_assignment,
    "administrator" => :last_avatar_administrator_assignment,
  }.freeze

  # FIXME: Violates Umaxica/NoConcernInclusionHooks; move the declarations in this block into each class that includes this concern.
  included do
    before_destroy :ensure_not_destroying_last_protected_assignment
    validate :ensure_not_demoting_last_protected_assignment, on: :update
  end

  private

  def ensure_not_destroying_last_protected_assignment
    return unless protected_role?(role)

    avatar.with_lock do
      next if another_active_assignment_for_role?(role)

      add_last_role_error(role)
      throw(:abort)
    end
  end

  def ensure_not_demoting_last_protected_assignment
    previous_role = role_in_database
    return unless protected_role?(previous_role)
    return if role == previous_role

    avatar.with_lock do
      next if another_active_assignment_for_role?(previous_role)

      add_last_role_error(previous_role)
    end
  end

  def another_active_assignment_for_role?(protected_role)
    self.class
      .where(avatar_id: avatar_id, role: protected_role)
      .where.not(id: id)
      .exists?
  end

  def protected_role?(candidate_role)
    PROTECTED_ROLES.include?(candidate_role)
  end

  def add_last_role_error(protected_role)
    errors.add(:base, LAST_ROLE_ERROR_BY_ROLE.fetch(protected_role))
  end
end
