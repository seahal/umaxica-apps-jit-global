# frozen_string_literal: true

class ValidateAvatarOwnershipPeriodTemporalExclusion < ActiveRecord::Migration[8.2]
  def up
    validate_check_constraint(
      :avatar_ownership_periods,
      name: AddAvatarOwnershipPeriodTemporalExclusion::CHECK_NAME,
    )
  end

  def down
    # PostgreSQL constraints cannot be returned to NOT VALID after validation.
  end
end
