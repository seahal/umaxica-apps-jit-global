# typed: false
# frozen_string_literal: true

# adr/unified-enforcement.md, D8: ending a Case closes all its own still-open Effects in the same
# transaction, then releases the principal's administrative lock only if no other Case's Principal
# Effect is still in force for them - the refcount rule.
#
# As with the apply operation, the release runs outside the transaction: the Case is ended whether
# or not the unlock succeeds, and a failed unlock must not resurrect a Case an operator has closed.
#
# This was EnforcementCaseApplicable#end_case!.
class EnforcementCaseEndOperation
  class OtherBlockingCaseInForce < StandardError; end

  class PrincipalAlreadyReleased < StandardError; end

  class NestedStepUpTransactionError < StandardError; end

  public

  def self.call(...)
    new(...).call
  end

  def initialize(enforcement_case:, reason:, ended_by_operator_public_id: nil,
                 step_up_token: nil, step_up_actor: nil, step_up_evidence: nil, recovery_ceremony: nil,
                 authorization_rule: nil)
    @enforcement_case = enforcement_case
    @reason = reason
    @ended_by_operator_public_id = ended_by_operator_public_id
    @step_up_token = step_up_token
    @step_up_actor = step_up_actor
    @step_up_evidence = step_up_evidence
    @recovery_ceremony = recovery_ceremony
    @authorization_rule = authorization_rule
    validate_step_up_pair!
  end

  def call
    unless EnforcementCaseApplicable::END_REASONS.include?(reason.to_s)
      raise ArgumentError, "reason must be one of #{EnforcementCaseApplicable::END_REASONS}"
    end

    validate_recovery_pair!

    committed_end_reason =
      if step_up_token
        commit_end_with_step_up_authority!
      else
        commit_end_transaction!
      end

    release_principal_access_effect!
    enforcement_case.write_audit_event_once!(audit_event_type(committed_end_reason), **audit_actor)

    true
  end

  # The state transaction may already have committed when a release or audit
  # side effect fails. Retry only the convergent work; do not write the Case
  # state a second time or treat a missing Solid Queue execution as a rollback.
  def reconcile
    return false if enforcement_case.ended_at.blank?

    release_principal_access_effect!
    enforcement_case.write_audit_event_once!(audit_event_type(enforcement_case.end_reason), **audit_actor)
    true
  end

  private

  attr_reader :enforcement_case, :reason, :ended_by_operator_public_id, :step_up_token, :step_up_actor,
              :step_up_evidence, :recovery_ceremony, :authorization_rule

  def commit_end!
    return if enforcement_case.ended_at.present?

    now = Time.current
    enforcement_case.update!(
      ended_at: now, end_reason: reason, ended_by_operator_public_id: ended_by_operator_public_id,
    )
    effect = enforcement_case.principal_effect_record
    effect&.update!(ended_at: now)
    # rubocop:disable Rails/SkipsModelValidations
    enforcement_case.authentication_method_effects.where(ended_at: nil).update_all(ended_at: now)
    enforcement_case.identifier_effects.where(ended_at: nil).update_all(ended_at: now)
    # rubocop:enable Rails/SkipsModelValidations
    authorize_step_up!(step_up_actor) if step_up_token
    verify_step_up!
  end

  def commit_end_transaction!
    committed_end_reason = nil
    enforcement_case.class.transaction do
      enforcement_case.with_lock do
        if recovery_ceremony
          recovery_ceremony.with_lock do
            validate_locked_recovery!
            commit_end!
            recovery_ceremony.consume!
          end
        else
          commit_end!
        end

        committed_end_reason = enforcement_case.end_reason
      end
    end
    committed_end_reason
  end

  def commit_end_with_step_up_authority!
    unless step_up_actor.class.lease_connection.open_transactions.zero? &&
        step_up_token.class.lease_connection.open_transactions.zero? &&
        enforcement_case.class.lease_connection.open_transactions.zero?
      raise NestedStepUpTransactionError,
            "Step-Up Case end must own the actor, OP and Case transactions"
    end

    # Hold the actor first and retain OP evidence locks through the Case commit. Principal access
    # release and audit convergence happen after both transaction boundaries close.
    step_up_actor.with_lock do
      step_up_token.class.transaction { commit_end_transaction! }
    end
  end

  def authorize_step_up!(locked_actor)
    policy = EnforcementCasePolicy.new(enforcement_case, user: locked_actor)
    authorized =
      case authorization_rule
      when :release
        policy.apply(:release?)
      when :review_appeal
        policy.apply(:review_appeal?)
      else
        raise ArgumentError, "Step-Up Case end requires an explicit authorization rule"
      end
    return if authorized

    raise EnforcementCaseAuthorizationRejected, "operator is no longer authorized to end this Case"
  end

  def validate_recovery_pair!
    return if reason.to_s != "verification_completed" && recovery_ceremony.nil?
    return if reason.to_s == "verification_completed" && enforcement_case.is_a?(AppEnforcementCase) &&
      recovery_ceremony.is_a?(ClientEnforcementRecoveryCeremony)

    raise ArgumentError, "verification completion requires its APP recovery ceremony"
  end

  def validate_locked_recovery!
    valid_subject = Client.exists?(id: recovery_ceremony.client_id, public_id: enforcement_case.principal_public_id)
    return if recovery_ceremony.active? && valid_subject && enforcement_case.in_force? &&
      enforcement_case.kind == "security_lock" && enforcement_case.visibility == "visible" &&
      enforcement_case.release_mode == "verification_required"

    raise ActiveRecord::RecordNotFound, "recovery authority is unavailable"
  end

  def validate_step_up_pair!
    return if step_up_token.nil? && step_up_actor.nil? && step_up_evidence.nil? && ended_by_operator_public_id.nil?

    valid_actor_and_token = step_up_token.is_a?(OperatorToken) && step_up_actor.is_a?(Operator) &&
      step_up_actor.persisted? && step_up_actor.public_id == ended_by_operator_public_id &&
      step_up_token.staff_id == step_up_actor.id
    raise ArgumentError, "operator enforcement end Step-Up actor and token must be supplied together" unless
      valid_actor_and_token
    unless %i(release review_appeal).include?(authorization_rule)
      raise ArgumentError, "operator enforcement end requires an explicit authorization rule"
    end
    return if step_up_evidence.is_a?(StepUpEvidenceValue)
    raise TokenStatusManagement::StepUpEvidenceUnavailable, "Enforcement end requires current Step-Up" if
      step_up_evidence.nil?

    raise ArgumentError, "operator enforcement end requires its bound Step-Up actor, token and evidence"
  end

  def verify_step_up!
    return if step_up_token.nil?
    return if StepUpEvidenceVerifier.call(evidence: step_up_evidence, actor: step_up_actor, token: step_up_token)

    raise TokenStatusManagement::StepUpEvidenceUnavailable, "Enforcement end requires current Step-Up"
  end

  # The operator who ended the Case; nil when no operator did (expiry, principal verification).
  def audit_actor
    { actor_operator_public_id: enforcement_case.ended_by_operator_public_id }
  end

  def audit_event_type(end_reason)
    (end_reason == "expired") ? "expired" : "ended"
  end

  def release_principal_access_effect!
    effect = enforcement_case.principal_effect_record
    return unless effect&.access_blocking?

    principal = enforcement_case.class.principal_class.find_by!(public_id: enforcement_case.principal_public_id)
    operator = ::Operator.find_by!(public_id: enforcement_case.applied_by_operator_public_id)

    AdministrativeAccessLock.unlock!(
      account: principal,
      operator: operator,
      reason_code: enforcement_case.reason_code,
      ticket_id: enforcement_case.ticket_id,
      metadata: { enforcement_case_public_id: enforcement_case.public_id },
    ) do
      raise OtherBlockingCaseInForce if other_blocking_case_in_force?
      raise PrincipalAlreadyReleased if principal_release_recorded?(principal)
    end
  rescue OtherBlockingCaseInForce, PrincipalAlreadyReleased
    nil
  end

  def principal_release_recorded?(principal)
    ChronicleRecord.connected_to(role: :writing) do
      AccountAccessEvent.where(
        account_type: principal.class.name, account_id: principal.id,
        event_type: AccountAccessEvent::EVENT_TYPE_ADMIN_UNLOCK,
      ).exists?(["metadata @> ?::jsonb", { enforcement_case_public_id: enforcement_case.public_id }.to_json])
    end
  end

  def other_blocking_case_in_force?
    enforcement_case.class.in_force
      .where(principal_public_id: enforcement_case.principal_public_id)
      .where.not(id: enforcement_case.id)
      .joins(:principal_effect)
      .merge(enforcement_case.class.reflect_on_association(:principal_effect).klass.where(access_blocking: true))
      .exists?
  end
end
