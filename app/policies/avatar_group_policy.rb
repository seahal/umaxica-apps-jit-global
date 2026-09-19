# typed: false
# frozen_string_literal: true

class AvatarGroupPolicy < ApplicationPolicy
  def index?
    user.is_a?(Client)
  end

  def show?
    same_selected_account?
  end

  # The same boundary as same_selected_account?, as a relation: the selected
  # account's app groups, archived ones included.
  relation_scope do |relation|
    account_public_id = Actor.selection.account_public_id
    next relation.none unless user.is_a?(Client) && account_public_id.present?

    relation.where(account_surface: "app", account_public_id: account_public_id)
  end

  def create?
    user.is_a?(Client)
  end

  def update?
    same_selected_account? && record.active?
  end

  def destroy?
    same_selected_account? && record.active?
  end

  private

  def same_selected_account?
    user.is_a?(Client) &&
      record.is_a?(AvatarGroup) &&
      record.account_surface == "app" &&
      record.account_public_id == Actor.selection.account_public_id
  end
end
