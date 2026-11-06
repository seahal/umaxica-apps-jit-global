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

  class NestedStepUpTransactionError < StandardError; end

  def self.call(...)
    new(...).call
  end

  # `actor_operator_public_id` is the operator running this apply (the opener on the direct path,
  # the approver on the approval path); it is recorded on the `applied` event.
  def initialize(enforcement_case:, actor_operator_public_id:, step_up_token: nil, step_up_actor: nil,
                 step_up_evidence: nil, authorization_rule: nil)
    @enforcement_case = enforcement_case
    @actor_operator_public_id = actor_operator_public_id
    @step_up_token = step_up_token
    @step_up_actor = step_up_actor
    @step_up_evidence = step_up_evidence
    @authorization_rule = authorization_rule
    validate_step_up_pair!
  end

  def call
    # A failure here rolls the transaction back: nothing was decided or performed, so the Case keeps
    # its committed state (draft or pending_approval) and the error propagates unchanged.
    if step_up_token
      commit_case_with_step_up_authority!
    else
      commit_case!
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

  attr_reader :enforcement_case, :actor_operator_public_id, :step_up_token, :step_up_actor, :step_up_evidence,
              :authorization_rule

  def commit_case!(locked_actor: nil)
    enforcement_case.class.transaction do
      current = enforcement_case.persisted? ? enforcement_case.class.lock.find(enforcement_case.id) : enforcement_case
      validate_current_case!(current)
      authorize_step_up!(current, locked_actor) if locked_actor
      enforcement_case.close_superseded_effects!
      enforcement_case.state = "active"
      verify_step_up!
      enforcement_case.save!
    end
  end

  def commit_case_with_step_up_authority!
    unless step_up_actor.class.lease_connection.open_transactions.zero? &&
        step_up_token.class.lease_connection.open_transactions.zero? &&
        enforcement_case.class.lease_connection.open_transactions.zero?
      raise NestedStepUpTransactionError,
            "Step-Up Case apply must own the actor, OP and Case transactions"
    end

    # The OP transaction begins only after the Operator row is locked. `commit_case!` keeps its
    # Case write and the final locked evidence recheck inside this boundary. Post-commit account,
    # session and audit convergence remains outside both transactions.
    step_up_actor.with_lock do
      step_up_token.class.transaction { commit_case!(locked_actor: step_up_actor) }
    end
  end

  def authorize_step_up!(current_case, locked_actor)
    authorized =
      case authorization_rule
      when :create
        EnforcementCasePolicy.new(current_case, user: locked_actor).apply(:create?)
      when :approve
        EnforcementCasePolicy.new(current_case, user: locked_actor).apply(:approve?)
      else
        raise ArgumentError, "Step-Up Case apply requires an explicit authorization rule"
      end
    return if authorized

    raise EnforcementCaseAuthorizationRejected, "operator is no longer authorized to apply this Case"
  end

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
    return if step_up_token.nil? && step_up_actor.nil? && step_up_evidence.nil?

    valid_actor_and_token = step_up_token.is_a?(OperatorToken) && step_up_actor.is_a?(Operator) &&
      step_up_actor.persisted? && step_up_actor.public_id == actor_operator_public_id &&
      step_up_token.staff_id == step_up_actor.id
    raise ArgumentError, "enforcement apply Step-Up actor and token must be supplied together" unless
      valid_actor_and_token
    unless %i(create approve).include?(authorization_rule)
      raise ArgumentError, "enforcement apply requires an explicit authorization rule"
    end
    return if step_up_evidence.is_a?(StepUpEvidenceValue)
    raise TokenStatusManagement::StepUpEvidenceUnavailable, "Enforcement apply requires current Step-Up" if
      step_up_evidence.nil?

    raise ArgumentError, "enforcement apply Step-Up actor, token and evidence must be supplied together"
  end

  def verify_step_up!
    return if step_up_token.nil?
    return if StepUpEvidenceVerifier.call(evidence: step_up_evidence, actor: step_up_actor, token: step_up_token)

    raise TokenStatusManagement::StepUpEvidenceUnavailable, "Enforcement apply requires current Step-Up"
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
