# typed: false
# frozen_string_literal: true

# adr/operator-capability-authorization.md, IAM. Granting is authorized separately from holding:
# the granter needs iam.capability.grant and must itself hold the capability being delegated, may
# not grant to themselves, and may never delegate the bootstrap-only IAM capabilities.
class OperatorCapabilityGrantPolicy < ApplicationPolicy
  public

  def index?
    operator_capability?(OperatorCapabilityGrant::IAM_CAPABILITY_READ)
  end

  def show?
    index?
  end

  # The confirmation screen, before a target or capability has been chosen.
  def grant_screen?
    index? && operator_capability?(OperatorCapabilityGrant::IAM_CAPABILITY_GRANT)
  end

  def create?
    return false unless grant_screen?
    return false if record.operator_id.blank? || record.operator_id == user.id
    return false unless OperatorCapabilityGrant::CAPABILITIES.include?(record.capability)
    return false if OperatorCapabilityGrant::BOOTSTRAP_ONLY_CAPABILITIES.include?(record.capability)

    user.capability?(record.capability)
  end

  def revoke?
    index? && operator_capability?(OperatorCapabilityGrant::IAM_CAPABILITY_REVOKE) && !record.revoked?
  end
end
