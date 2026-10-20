# typed: false
# frozen_string_literal: true

class AvatarEnterpriseToEnterpriseTransferDetail < AvatarRecord
  belongs_to :transfer_reservation,
             class_name: "AvatarTransferReservation",
             inverse_of: :enterprise_to_enterprise_detail
  belongs_to :source_ownership_period,
             class_name: "AvatarEnterpriseOwnershipPeriod",
             inverse_of: false

  validates :transfer_reservation_id, uniqueness: true, on: :create

  validates :source_enterprise_public_id, :destination_enterprise_public_id, :request_actor_public_id,
            presence: true
  validates :accept_actor_public_id, :destination_enterprise_public_id, :request_actor_public_id,
            :source_enterprise_public_id, length: { maximum: 255 }
end
