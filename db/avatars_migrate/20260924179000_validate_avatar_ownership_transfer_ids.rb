# frozen_string_literal: true

class ValidateAvatarOwnershipTransferIds < ActiveRecord::Migration[8.2]
  def up
    validate_check_constraint(
      :avatar_ownership_transfers,
      name: "chk_avatar_ownership_transfer_nonblank_ids",
    )
  end

  def down
    # PostgreSQL does not support returning a validated constraint to NOT VALID.
  end
end
