# typed: false
# frozen_string_literal: true

class AvatarEnterpriseToBureauTransferDetail < AvatarRecord
  belongs_to :transfer_reservation,
             class_name: "AvatarTransferReservation",
             inverse_of: :enterprise_to_bureau_detail
  belongs_to :source_ownership_period,
             class_name: "AvatarEnterpriseOwnershipPeriod",
             inverse_of: false

  validates :source_enterprise_public_id, :destination_bureau_public_id, :request_actor_public_id,
            presence: true
end
