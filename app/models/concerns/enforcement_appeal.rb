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

  def redact!
    update!(statement: nil, state: "redacted", redacted_at: Time.current)
  end

  def submit!
    save!
    # Submitted by the principal, not an operator.
    enforcement_case.write_audit_event_once!("appeal_submitted", actor_operator_public_id: nil)
  end

  def resolve!(reviewer_operator_public_id:, resolution_code:, step_up_token: nil, step_up_requirement: nil)
    raise InvalidResolutionError, "unsupported appeal resolution" unless RESOLUTION_CODES.include?(resolution_code.to_s)

    validate_step_up_pair!(
      reviewer_operator_public_id, step_up_token, step_up_requirement,
    )

    transaction do
      lock!
      raise InvalidResolutionError, "appeal has already been resolved" unless %w(submitted under_review).include?(state)

      self.reviewer_operator_public_id = reviewer_operator_public_id
      self.resolution_code = resolution_code
      validate_reviewer_separation!

      if resolution_code == "approved"
        enforcement_case.lock!
        raise InvalidResolutionError, "enforcement case is no longer active" unless enforcement_case.in_force?
      end

      update!(
        state: resolution_code,
        reviewed_at: Time.current,
      )
      step_up_token&.consume_step_up_evidence!(requirement: step_up_requirement)
    end

    EnforcementCaseEndOperation.call(
      enforcement_case: enforcement_case, reason: "appeal_approved",
      ended_by_operator_public_id: reviewer_operator_public_id,
    ) if resolution_code == "approved"
    enforcement_case.write_audit_event_once!(
      "appeal_#{resolution_code}", actor_operator_public_id: reviewer_operator_public_id,
    )
  end

  def redacted? = state == "redacted"

  private

  def validate_step_up_pair!(reviewer_public_id, token, requirement)
    return if token.nil? && requirement.nil?
    return if token.is_a?(OperatorToken) && requirement.is_a?(StepUpRequirement) &&
      requirement.scope == "enforcement_case_review_appeal" &&
      requirement.actor_ref == reviewer_public_id &&
      Operator.exists?(id: token.staff_id, public_id: reviewer_public_id) &&
      requirement.token_binding == token.public_id && requirement.audience == "step_up:org"

    raise ArgumentError, "enforcement appeal Step-Up token and requirement must be supplied together"
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
