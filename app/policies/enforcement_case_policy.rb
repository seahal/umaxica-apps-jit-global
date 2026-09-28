# typed: false
# frozen_string_literal: true

# adr/unified-enforcement.md, Authorization / Operator safety, and
# adr/operator-capability-authorization.md. Shared across the realm-specific Case classes (set
# explicitly via `with: EnforcementCasePolicy`). Every rule resolves the record's realm through a
# fixed case on the Case class and checks that realm's own capability, so an app grant never
# reaches a com Case and the reverse.
#
# Org-realm Cases act on Operators. No capability for them is defined, so every rule denies them;
# operator discipline is not derived from app/com administration.
#
# Self-action denial and approval separation are also CHECK constraints (D12); this policy is the
# operator-facing gate, not the sole boundary.
class EnforcementCasePolicy < ApplicationPolicy
  def index?
    realm_capability?(read: true)
  end

  def show?
    index?
  end

  def create?
    realm_capability?(
      app: OperatorCapabilityGrant::ENFORCEMENT_APPLY_APP,
      com: OperatorCapabilityGrant::ENFORCEMENT_APPLY_COM,
    )
  end

  def approve?
    realm_capability?(
      app: OperatorCapabilityGrant::ENFORCEMENT_APPROVE_APP,
      com: OperatorCapabilityGrant::ENFORCEMENT_APPROVE_COM,
    ) && record.applied_by_operator_public_id != user.public_id
  end

  def release?
    realm_capability?(
      app: OperatorCapabilityGrant::ENFORCEMENT_RELEASE_APP,
      com: OperatorCapabilityGrant::ENFORCEMENT_RELEASE_COM,
    )
  end

  def review_appeal?
    realm_capability?(
      app: OperatorCapabilityGrant::ENFORCEMENT_REVIEW_APPEAL_APP,
      com: OperatorCapabilityGrant::ENFORCEMENT_REVIEW_APPEAL_COM,
    )
  end

  private

  # Every mutation also requires the realm's read capability: the operator is shown the Case before
  # acting on it, and a mutation-only grant would act blind.
  def realm_capability?(read: false, app: nil, com: nil)
    read_capability, mutation_capability =
      case record
      when ::AppEnforcementCase then [OperatorCapabilityGrant::ENFORCEMENT_READ_APP, app]
      when ::ComEnforcementCase then [OperatorCapabilityGrant::ENFORCEMENT_READ_COM, com]
      else return false
      end
    return false unless operator_capability?(read_capability)
    return true if read

    mutation_capability.present? && operator_capability?(mutation_capability)
  end
end
