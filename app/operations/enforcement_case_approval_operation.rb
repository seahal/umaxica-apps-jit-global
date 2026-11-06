# frozen_string_literal: true

# Owns the Support Case approval-request and approver-claim writes that require Step-Up.
class EnforcementCaseApprovalOperation
  class ClaimConflictError < StandardError; end

  class << self
    public

    def request!(enforcement_case:, actor:, token:, evidence:)
      validate_step_up!(actor:, token:, evidence:)
      raise ArgumentError, "approval request requires a Case that requires approval" unless
        enforcement_case.requires_approval?

      ensure_outermost_transactions!(actor:, token:, source: enforcement_case)
      actor.with_lock do
        token.class.transaction do
          enforcement_case.class.transaction do
            enforcement_case.state = "pending_approval"
            unless EnforcementCasePolicy.new(enforcement_case, user: actor).apply(:create?)
              raise EnforcementCaseAuthorizationRejected, "operator is no longer authorized to create this Case"
            end

            enforcement_case.save!
            enforcement_case.write_audit_event_once!(
              "approval_requested",
              actor_operator_public_id: actor.public_id,
            )
            verify_step_up!(actor:, token:, evidence:)
          end
        end
      end
    end

    def claim!(enforcement_case:, actor:, token:, evidence:)
      validate_step_up!(actor:, token:, evidence:)
      ensure_outermost_transactions!(actor:, token:, source: enforcement_case)

      actor.with_lock do
        token.class.transaction do
          enforcement_case.with_lock do
            unless enforcement_case.state == "pending_approval" &&
                enforcement_case.approved_by_operator_public_id.nil?
              raise ClaimConflictError
            end

            unless EnforcementCasePolicy.new(enforcement_case, user: actor).apply(:approve?)
              raise EnforcementCaseAuthorizationRejected, "operator is no longer authorized to approve this Case"
            end

            enforcement_case.update!(approved_by_operator_public_id: actor.public_id)
            verify_step_up!(actor:, token:, evidence:)
          end
        end
      end
    end

    private

    def validate_step_up!(actor:, token:, evidence:)
      unless actor.is_a?(Operator) && actor.persisted? && token.is_a?(OperatorToken) && token.staff_id == actor.id
        raise ArgumentError, "enforcement Case approval requires its bound Operator and token"
      end
      return if evidence.is_a?(StepUpEvidenceValue)

      raise TokenStatusManagement::StepUpEvidenceUnavailable, "enforcement Case approval requires current Step-Up"
    end

    def ensure_outermost_transactions!(actor:, token:, source:)
      return if actor.class.lease_connection.open_transactions.zero? &&
        token.class.lease_connection.open_transactions.zero? &&
        source.class.lease_connection.open_transactions.zero?

      raise ArgumentError, "enforcement Case approval must own the actor, OP and Case transactions"
    end

    def verify_step_up!(actor:, token:, evidence:)
      return if StepUpEvidenceVerifier.call(evidence:, actor:, token:)

      raise TokenStatusManagement::StepUpEvidenceUnavailable, "enforcement Case approval requires current Step-Up"
    end
  end
end
