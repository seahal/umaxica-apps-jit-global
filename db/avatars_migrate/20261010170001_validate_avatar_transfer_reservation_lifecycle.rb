# frozen_string_literal: true

class ValidateAvatarTransferReservationLifecycle < ActiveRecord::Migration[8.2]
  TABLE = :avatar_transfer_reservations
  EXPIRY_CONSTRAINT = "chk_avatar_transfer_reservations_expiry_after_request"

  def up
    validate_check_constraint(TABLE, name: EXPIRY_CONSTRAINT)
  end

  def down
    # Constraint validation is metadata; the preceding migration owns its removal.
  end
end
