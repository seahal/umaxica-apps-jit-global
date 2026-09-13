# typed: false
# frozen_string_literal: true

# Authorization policy for User resource management
# Controls who can view, create, update, and delete users
class ClientPolicy < ApplicationPolicy
  def index?
    # Only staff managers and above can view user list
    user.is_a?(Operator) && operator_or_manager?
  end

  def show?
    # Users can see their own profile, staff managers can see any user
    owner? || (user.is_a?(Operator) && operator_or_manager?)
  end

  def create?
    # Public registration is handled separately
    # Only staff operators can directly create users
    user.is_a?(Operator) && operator?
  end

  def update?
    # Users can update their own profile, staff managers can update any user
    owner? || (user.is_a?(Operator) && operator_or_manager?)
  end

  def destroy?
    # Only staff operators can delete users (or users can delete themselves via withdrawal)
    (owner? && user.is_a?(Client)) || (user.is_a?(Operator) && operator?)
  end

  def purge_sessions?
    user.is_a?(Operator)
  end

  relation_scope do |relation|
    if user.is_a?(Operator) && operator_or_manager?
      # Operator managers see all users
      relation.all
    elsif user.is_a?(Client)
      # Users see only themselves
      relation.where(id: user.id)
    else
      # Unauthenticated users see nothing
      relation.none
    end
  end
end
