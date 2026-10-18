# typed: false
# frozen_string_literal: true

class AvatarBureauToEnterpriseTransferDetail < AvatarRecord
  belongs_to :transfer_reservation,
             class_name: "AvatarTransferReservation",
             inverse_of: :bureau_to_enterprise_detail
  belongs_to :source_ownership_period,
             class_name: "AvatarBureauOwnershipPeriod",
             inverse_of: false

  validates :source_bureau_public_id, :destination_enterprise_public_id, :request_actor_public_id,
            presence: true
end
