# frozen_string_literal: true

class ValidateAvatarOwnerReference < ActiveRecord::Migration[8.2]
  def up
    validate_check_constraint(
      :avatar_ownership_periods,
      name: "chk_avatar_ownership_periods_owner_reference",
    )
  end

  def down
    # PostgreSQL constraints cannot be returned to NOT VALID after validation.
  end
end
