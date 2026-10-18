# typed: false
# frozen_string_literal: true

module AvatarOwnershipTransfers
  class ExpireReservationOperation < ApplicationService
    def initialize(reservation_public_id:, at: Avatar.database_now)
      super()
      @reservation_public_id = reservation_public_id.to_s
      @at = at
    end

    public

    def call
      reservation = AvatarTransferReservation.find_by(public_id: reservation_public_id)
      raise ActiveRecord::RecordNotFound, "Avatar transfer reservation not found" unless reservation

      result = nil
      AvatarRecord.transaction(requires_new: true) do
        locked = AvatarTransferReservation.lock.find(reservation.id)
        result = locked
        next unless locked.state == "pending" && locked.expires_at <= at

        locked.update!(state: "expired", completed_at: at)
        result = locked
      end
      result
    end

    private

    attr_reader :reservation_public_id, :at
  end
end
