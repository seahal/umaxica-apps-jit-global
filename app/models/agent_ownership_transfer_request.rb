# typed: false
# frozen_string_literal: true

class AgentOwnershipTransferRequest < OrgRpRecord
  include ::PublicId

  PENDING = "pending"
  STATUSES = %w(pending accepted rejected cancelled expired invalidated).freeze
  LIFETIME = 24.hours

  belongs_to :agent, inverse_of: :ownership_transfer_requests
  belongs_to :source_operator, class_name: "Operator", inverse_of: false
  belongs_to :destination_operator, class_name: "Operator", inverse_of: false

  scope :pending, -> { where(status: PENDING) }
  scope :due, ->(now = Time.current) { pending.where(expires_at: ..now) }

  validates :status, inclusion: { in: STATUSES }
  validates :expected_ownership_revision, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validate :parties_must_differ
  validate :expiry_must_follow_request

  private

  def parties_must_differ
    return if source_operator_id.blank? || destination_operator_id.blank?
    return unless source_operator_id == destination_operator_id

    errors.add(:destination_operator_id, "must differ from source_operator_id")
  end

  def expiry_must_follow_request
    return if requested_at.blank? || expires_at.blank?
    return if requested_at < expires_at

    errors.add(:expires_at, "must be after requested_at")
  end
end
