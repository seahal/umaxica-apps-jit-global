# typed: false
# frozen_string_literal: true

class IndividualOwnershipTransferRequest < ComRpRecord
  include ::PublicId

  PENDING = "pending"
  STATUSES = %w(pending accepted rejected cancelled expired invalidated).freeze
  LIFETIME = 24.hours

  belongs_to :individual, inverse_of: :ownership_transfer_requests
  belongs_to :source_visitor, class_name: "Visitor", inverse_of: false
  belongs_to :destination_visitor, class_name: "Visitor", inverse_of: false

  scope :pending, -> { where(status: PENDING) }
  scope :due, ->(now = Time.current) { pending.where(expires_at: ..now) }

  validates :status, inclusion: { in: STATUSES }
  validates :expected_ownership_revision, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validate :parties_must_differ
  validate :expiry_must_follow_request

  private

  def parties_must_differ
    return if source_visitor_id.blank? || destination_visitor_id.blank?
    return unless source_visitor_id == destination_visitor_id

    errors.add(:destination_visitor_id, "must differ from source_visitor_id")
  end

  def expiry_must_follow_request
    return if requested_at.blank? || expires_at.blank?
    return if requested_at < expires_at

    errors.add(:expires_at, "must be after requested_at")
  end
end
