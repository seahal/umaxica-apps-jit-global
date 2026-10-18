# frozen_string_literal: true

# Ownership layer for app Secret management. Mutating callers must additionally
# enforce their operation-specific Step-Up requirement and current session binding.
class ClientSecretCredentialPolicy < ApplicationPolicy
  public

  def index?
    persisted_client?
  end

  def create?
    persisted_client?
  end

  def show?
    credential_owner?
  end

  def update?
    credential_owner?
  end

  def destroy?
    credential_owner?
  end

  relation_scope do |relation|
    return relation.none unless persisted_client?

    relation.where(client_id: user.id)
  end

  private

  def persisted_client?
    user.is_a?(Client) && user.persisted?
  end

  def credential_owner?
    persisted_client? && record.is_a?(ClientSecretCredential) &&
      record.persisted? && record.client_id == user.id
  end
end
