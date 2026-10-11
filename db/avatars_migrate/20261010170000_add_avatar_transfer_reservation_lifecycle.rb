# frozen_string_literal: true

class AddAvatarTransferReservationLifecycle < ActiveRecord::Migration[8.2]
  TABLE = :avatar_transfer_reservations
  EXPIRY_CONSTRAINT = "chk_avatar_transfer_reservations_expiry_after_request"

  def up
    # This registry is not deployed with retained rows yet. The volatile defaults keep direct
    # SQL inserts inside the same five-day contract; normal writes supply both values explicitly.
    safety_assured do
      add_column(TABLE, :requested_at, :datetime, null: false, default: -> { "CURRENT_TIMESTAMP" })
      add_column(
        TABLE,
        :expires_at,
        :datetime,
        null: false,
        default: -> { "CURRENT_TIMESTAMP + INTERVAL '5 days'" },
      )
    end
    add_check_constraint(
      TABLE,
      "expires_at > requested_at",
      name: EXPIRY_CONSTRAINT,
      validate: false,
    )
  end

  def down
    safety_assured { remove_check_constraint(TABLE, name: EXPIRY_CONSTRAINT) }
    remove_column(TABLE, :expires_at)
    remove_column(TABLE, :requested_at)
  end
end
