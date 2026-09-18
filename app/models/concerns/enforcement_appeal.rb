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
    enforcement_case.write_audit_event_once!("appeal_submitted")
  end

  def resolve!(reviewer_operator_public_id:, resolution_code:)
    raise InvalidResolutionError, "unsupported appeal resolution" unless RESOLUTION_CODES.include?(resolution_code.to_s)

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
    end

    EnforcementCaseEndOperation.call(
      enforcement_case: enforcement_case, reason: "appeal_approved",
      ended_by_operator_public_id: reviewer_operator_public_id,
    ) if resolution_code == "approved"
    enforcement_case.write_audit_event_once!("appeal_#{resolution_code}")
  end

  def redacted? = state == "redacted"

  private

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
