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
  class CaseNoLongerActive < StandardError; end

  def self.call(...)
    new(...).call
  end

  # `actor_operator_public_id` is the operator running this apply (the opener on the direct path,
  # the approver on the approval path); it is recorded on the `applied` event.
  def initialize(enforcement_case:, actor_operator_public_id:, step_up_token: nil, step_up_requirement: nil)
    @enforcement_case = enforcement_case
    @actor_operator_public_id = actor_operator_public_id
    @step_up_token = step_up_token
    @step_up_requirement = step_up_requirement
    validate_step_up_pair!
  end

  def call
    # A failure here rolls the transaction back: nothing was decided or performed, so the Case keeps
    # its committed state (draft or pending_approval) and the error propagates unchanged.
    enforcement_case.class.transaction do
      current = enforcement_case.persisted? ? enforcement_case.class.lock.find(enforcement_case.id) : enforcement_case
      validate_current_case!(current)
      enforcement_case.close_superseded_effects!
      enforcement_case.state = "active"
      enforcement_case.save!
      step_up_token&.consume_step_up_evidence!(requirement: step_up_requirement)
    end

    perform_committed_side_effects!
  end

  # Retry only the principal-side effect for an already committed decision. The effect itself
  # rechecks the Case under the principal lock so an end racing this retry cannot relock it.
  def reconcile_principal_access!
    perform_principal_access_effect!
  end
  public :reconcile_principal_access!

  private

  # The decision remains active when a downstream effect fails.
  def perform_committed_side_effects!
    return false unless perform_principal_access_effect!

    enforcement_case.with_lock do
      next false unless enforcement_case.state == "active" && enforcement_case.ended_at.nil?

      enforcement_case.revoke_method_sessions!
      write_approval_event!
      enforcement_case.write_audit_event_once!("applied", actor_operator_public_id: actor_operator_public_id)
      true
    end
  end

  attr_reader :enforcement_case, :actor_operator_public_id, :step_up_token, :step_up_requirement

  def validate_current_case!(current)
    unless %w(draft pending_approval).include?(current.state)
      raise EnforcementCaseApplicable::InvalidStateTransitionError,
            "Case #{current.public_id} is already #{current.state}"
    end
    if current.requires_approval? && current.approved_by_operator_public_id.blank?
      raise EnforcementCaseApplicable::ApprovalRequiredError,
            "Case #{current.public_id} requires approval before it can be applied"
    end
    return if current.equal?(enforcement_case) || current.attributes == enforcement_case.attributes

    raise EnforcementCaseApplicable::InvalidStateTransitionError, "Case #{current.public_id} changed before apply"
  end

  def validate_step_up_pair!
    return if step_up_token.nil? && step_up_requirement.nil?
    return if step_up_token.is_a?(OperatorToken) && step_up_requirement.is_a?(StepUpRequirement) &&
      %w(enforcement_case_apply enforcement_case_approve).include?(step_up_requirement.scope) &&
      step_up_requirement.actor_ref == actor_operator_public_id &&
      Operator.exists?(id: step_up_token.staff_id, public_id: actor_operator_public_id) &&
      step_up_requirement.token_binding == step_up_token.public_id &&
      step_up_requirement.audience == "step_up:org"

    raise ArgumentError, "enforcement apply Step-Up token and requirement must be supplied together"
  end

  # An approved Case records who approved it before it records the apply. Both writes are
  # write-once, so EnforcementReconciliationJob can repeat them after an audit delivery failure.
  def write_approval_event!
    approver = enforcement_case.approved_by_operator_public_id
    return if approver.blank?

    enforcement_case.write_audit_event_once!("approved", actor_operator_public_id: approver)
  end

  def perform_principal_access_effect!
    effect = enforcement_case.principal_effect_record
    return true unless effect&.access_blocking?

    principal = enforcement_case.class.principal_class.find_by!(public_id: enforcement_case.principal_public_id)
    operator = ::Operator.find_by!(public_id: enforcement_case.applied_by_operator_public_id)

    AdministrativeAccessLock.lock!(
      account: principal,
      operator: operator,
      reason_code: enforcement_case.reason_code,
      reason_note: enforcement_case.reason_note,
      ticket_id: enforcement_case.ticket_id,
      metadata: { enforcement_case_public_id: enforcement_case.public_id },
    ) do
      enforcement_case.lock!
      raise CaseNoLongerActive unless enforcement_case.state == "active" && enforcement_case.ended_at.nil?
    end
    true
  rescue CaseNoLongerActive
    false
  end
end
