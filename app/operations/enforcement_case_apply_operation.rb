# typed: false
# frozen_string_literal: true

# adr/unified-enforcement.md: moves a draft or approved Case to active and performs the effects
# that decision implies.
#
# The state change commits in a transaction; the side effects run after it, deliberately. A
# committed security decision must never be rolled back because a downstream effect failed, so a
# raise here leaves the Case active and the convergence columns null for
# EnforcementReconciliationJob to pick up (adr/unified-enforcement.md, Failure recovery /
# Reconciliation).
#
# This was EnforcementCaseApplicable#apply!. It is a use case, not model behaviour: it coordinates
# an account lock and a session revocation that both reach outside the Case aggregate.
class EnforcementCaseApplyOperation
  def self.call(...)
    new(...).call
  end

  def initialize(enforcement_case:)
    @enforcement_case = enforcement_case
  end

  def call
    unless %w(draft pending_approval).include?(enforcement_case.state)
      raise EnforcementCaseApplicable::InvalidStateTransitionError,
            "Case #{enforcement_case.public_id} is already #{enforcement_case.state}"
    end
    if enforcement_case.requires_approval? && enforcement_case.approved_by_operator_public_id.blank?
      raise EnforcementCaseApplicable::ApprovalRequiredError,
            "Case #{enforcement_case.public_id} requires approval before it can be applied"
    end

    enforcement_case.class.transaction do
      enforcement_case.close_superseded_effects!
      enforcement_case.state = "active"
      enforcement_case.save!
    end

    perform_principal_access_effect!
    enforcement_case.revoke_method_sessions!
    enforcement_case.write_audit_event_once!("applied")

    true
  rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique => e
    # rubocop:disable Rails/SkipsModelValidations
    enforcement_case.update_column(:state, "failed") if enforcement_case.persisted?
    # rubocop:enable Rails/SkipsModelValidations
    raise e
  end

  private

  attr_reader :enforcement_case

  def perform_principal_access_effect!
    effect = enforcement_case.principal_effect
    return unless effect&.access_blocking?

    principal = enforcement_case.class.principal_class.find_by!(public_id: enforcement_case.principal_public_id)
    operator = ::Operator.find_by!(public_id: enforcement_case.applied_by_operator_public_id)

    AdministrativeAccessLock.lock!(
      account: principal,
      operator: operator,
      reason_code: enforcement_case.reason_code,
      reason_note: enforcement_case.reason_note,
      ticket_id: enforcement_case.ticket_id,
      metadata: { enforcement_case_public_id: enforcement_case.public_id },
    )
  end
end
