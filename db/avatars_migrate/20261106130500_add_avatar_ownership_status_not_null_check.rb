# frozen_string_literal: true

class AddAvatarOwnershipStatusNotNullCheck < ActiveRecord::Migration[8.2]
  TABLE = :avatar_ownership_periods
  COLUMN = :avatar_ownership_status_id
  CHECK_NAME = "chk_avatar_ownership_periods_status_id_nn"

  def change
    add_check_constraint(TABLE, "#{COLUMN} IS NOT NULL", name: CHECK_NAME, validate: false)
  end
end
