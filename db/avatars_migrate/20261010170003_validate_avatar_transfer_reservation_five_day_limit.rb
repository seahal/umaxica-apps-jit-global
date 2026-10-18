# frozen_string_literal: true

class ValidateAvatarTransferReservationFiveDayLimit < ActiveRecord::Migration[8.2]
  TABLE = :avatar_transfer_reservations
  CONSTRAINT = "chk_avatar_transfer_reservations_within_five_days"

  def up
    validate_check_constraint(TABLE, name: CONSTRAINT)
  end

  def down
    # Constraint validation is metadata; the preceding migration owns its removal.
  end
end
