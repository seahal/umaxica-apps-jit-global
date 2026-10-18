# typed: false
# frozen_string_literal: true

class AvatarTransferReservation < AvatarRecord
  include ::PublicId

  OPERATION_KINDS = %w(
    enterprise_to_enterprise
    enterprise_to_bureau
    bureau_to_enterprise
    bureau_to_bureau
  ).freeze
  STATES = %w(pending accepted cancelled expired).freeze

  belongs_to :avatar, inverse_of: :transfer_reservations
  has_one :enterprise_to_enterprise_detail,
          class_name: "AvatarEnterpriseToEnterpriseTransferDetail",
          dependent: :restrict_with_error,
          inverse_of: :transfer_reservation
  has_one :enterprise_to_bureau_detail,
          class_name: "AvatarEnterpriseToBureauTransferDetail",
          dependent: :restrict_with_error,
          inverse_of: :transfer_reservation
  has_one :bureau_to_enterprise_detail,
          class_name: "AvatarBureauToEnterpriseTransferDetail",
          dependent: :restrict_with_error,
          inverse_of: :transfer_reservation
  has_one :bureau_to_bureau_detail,
          class_name: "AvatarBureauToBureauTransferDetail",
          dependent: :restrict_with_error,
          inverse_of: :transfer_reservation

  validates :operation_kind, inclusion: { in: OPERATION_KINDS }
  validates :state, inclusion: { in: STATES }
  validates :idempotency_key,
            format: { with: /\A[0-9a-f]{8}-[0-9a-f]{4}-[47][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}\z/ }
  validates :request_fingerprint, presence: true
  validate :expiry_follows_request

  scope :pending, -> { where(state: "pending") }

  private

  def expiry_follows_request
    return if requested_at.blank? || expires_at.blank? || expires_at > requested_at

    errors.add(:expires_at, "must be after requested_at")
  end
end
