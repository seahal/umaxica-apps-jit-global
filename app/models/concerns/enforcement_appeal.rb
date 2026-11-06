# typed: false
# frozen_string_literal: true

module EnforcementAppeal
  extend ActiveSupport::Concern

  STATES = %w(submitted under_review approved rejected redacted).freeze
  REASON_CODES = %w(incorrect_decision new_information other).freeze
  RESOLUTION_CODES = %w(approved rejected).freeze
  MAXIMUM_STATEMENT_LENGTH = 4_000

  class ReviewerSeparationError < StandardError; end

  class InvalidResolutionError < StandardError; end

  # FIXME: Violates Umaxica/NoConcernInclusionHooks; move the declarations in this block into each class that includes this concern.
  included do
    include ::PublicId

    encrypts :statement

    validates :state, presence: true, inclusion: { in: STATES }
    validates :reason_code, presence: true, inclusion: { in: REASON_CODES }
    validates :statement, presence: true, length: { maximum: MAXIMUM_STATEMENT_LENGTH }, unless: :redacted?
    validates :submitted_at, presence: true
    validates :resolution_code, inclusion: { in: RESOLUTION_CODES }, allow_nil: true
    validate :reviewer_is_separate_from_case_operators, if: :reviewer_operator_public_id?
  end

  public

  def redact!
    update!(statement: nil, state: "redacted", redacted_at: Time.current)
  end

  def submit!
    save!
    # Submitted by the principal, not an operator.
    enforcement_case.write_audit_event_once!("appeal_submitted", actor_operator_public_id: nil)
  end

  def resolve!(reviewer_operator_public_id:, resolution_code:, step_up_token: nil, step_up_actor: nil,
               step_up_evidence: nil)
    raise InvalidResolutionError, "unsupported appeal resolution" unless RESOLUTION_CODES.include?(resolution_code.to_s)

    validate_step_up_pair!(reviewer_operator_public_id, step_up_token, step_up_actor, step_up_evidence)
    commit_resolution!(
      reviewer_operator_public_id:, resolution_code:, step_up_token:, step_up_actor:, step_up_evidence:,
    )

    EnforcementCaseEndOperation.call(
      enforcement_case: enforcement_case, reason: "appeal_approved",
      ended_by_operator_public_id: reviewer_operator_public_id,
      step_up_token: step_up_token,
      step_up_actor: step_up_actor,
      step_up_evidence: step_up_evidence,
      authorization_rule: :review_appeal,
    ) if resolution_code == "approved"
    enforcement_case.write_audit_event_once!(
      "appeal_#{resolution_code}", actor_operator_public_id: reviewer_operator_public_id,
    )
  end

  def redacted? = state == "redacted"

  private

  def commit_resolution!(reviewer_operator_public_id:, resolution_code:, step_up_token:, step_up_actor:,
                         step_up_evidence:)
    if step_up_token
      ensure_outermost_step_up_transactions!(step_up_token:, step_up_actor:)
      # Resolve the appeal while the reviewer is locked before taking OP evidence locks. Any approved
      # Case release is a separate commit operation below, after this read-only OP transaction ends.
      step_up_actor.with_lock do
        step_up_token.class.transaction do
          write_resolution!(
            reviewer_operator_public_id:, resolution_code:, step_up_token:, step_up_actor:, step_up_evidence:,
          )
        end
      end
    else
      write_resolution!(
        reviewer_operator_public_id:, resolution_code:, step_up_token:, step_up_actor:, step_up_evidence:,
      )
    end
  end

  def ensure_outermost_step_up_transactions!(step_up_token:, step_up_actor:)
    return if step_up_actor.class.lease_connection.open_transactions.zero? &&
      step_up_token.class.lease_connection.open_transactions.zero? &&
      self.class.lease_connection.open_transactions.zero?

    raise ArgumentError, "Step-Up appeal resolution must own the actor, OP and appeal transactions"
  end

  def write_resolution!(reviewer_operator_public_id:, resolution_code:, step_up_token:, step_up_actor:,
                        step_up_evidence:)
    transaction do
      lock!
      unless %w(submitted under_review).include?(state)
        raise InvalidResolutionError, "appeal has already been resolved"
      end

      self.reviewer_operator_public_id = reviewer_operator_public_id
      self.resolution_code = resolution_code
      validate_reviewer_separation!

      if resolution_code == "approved"
        enforcement_case.lock!
        raise InvalidResolutionError, "enforcement case is no longer active" unless enforcement_case.in_force?
      end

      if step_up_token && !EnforcementCasePolicy.new(enforcement_case, user: step_up_actor).apply(:review_appeal?)
        raise EnforcementCaseAuthorizationRejected, "reviewer is no longer authorized to resolve this appeal"
      end

      update!(state: resolution_code, reviewed_at: Time.current)
      verify_step_up!(step_up_token:, step_up_actor:, step_up_evidence:)
    end
  end

  def validate_step_up_pair!(reviewer_public_id, token, actor, evidence)
    return if token.nil? && actor.nil? && evidence.nil?

    valid_actor_and_token = token.is_a?(OperatorToken) && actor.is_a?(Operator) && actor.persisted? &&
      actor.public_id == reviewer_public_id && token.staff_id == actor.id
    raise ArgumentError, "enforcement appeal reviewer and token must be supplied together" unless
      valid_actor_and_token
    return if evidence.is_a?(StepUpEvidenceValue)
    raise TokenStatusManagement::StepUpEvidenceUnavailable, "Enforcement appeal requires current Step-Up" if
      evidence.nil?

    raise ArgumentError, "enforcement appeal requires its bound Step-Up actor, token and evidence"
  end

  def verify_step_up!(step_up_token:, step_up_actor:, step_up_evidence:)
    return if step_up_token.nil?
    return if StepUpEvidenceVerifier.call(evidence: step_up_evidence, actor: step_up_actor, token: step_up_token)

    raise TokenStatusManagement::StepUpEvidenceUnavailable, "Enforcement appeal requires current Step-Up"
  end

  def reviewer_is_separate_from_case_operators
    return if reviewer_operator_public_id.blank?
    return if reviewer_operator_public_id != enforcement_case.applied_by_operator_public_id &&
      reviewer_operator_public_id != enforcement_case.approved_by_operator_public_id

    errors.add(:reviewer_operator_public_id, "must differ from the applying and approving operators")
  end

  def validate_reviewer_separation!
    return if reviewer_operator_public_id != enforcement_case.applied_by_operator_public_id &&
      reviewer_operator_public_id != enforcement_case.approved_by_operator_public_id

    raise ReviewerSeparationError, "appeal reviewer must differ from the applying and approving operators"
  end
end
