# frozen_string_literal: true

class AddAvatarTransferReservationFiveDayLimit < ActiveRecord::Migration[8.2]
  TABLE = :avatar_transfer_reservations
  CONSTRAINT = "chk_avatar_transfer_reservations_within_five_days"

  def up
    add_check_constraint(
      TABLE,
      "expires_at - requested_at <= interval '5 days'",
      name: CONSTRAINT,
      validate: false,
    )
  end

  def down
    safety_assured { remove_check_constraint(TABLE, name: CONSTRAINT) }
  end
end
