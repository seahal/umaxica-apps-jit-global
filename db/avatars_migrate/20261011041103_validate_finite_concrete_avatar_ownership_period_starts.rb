# frozen_string_literal: true

class ValidateFiniteConcreteAvatarOwnershipPeriodStarts < ActiveRecord::Migration[8.2]
  def up
    validate_check_constraint(
      :avatar_enterprise_ownership_periods,
      name: "chk_avatar_enterprise_ownership_periods_finite_start",
    )
    validate_check_constraint(
      :avatar_bureau_ownership_periods,
      name: "chk_avatar_bureau_ownership_periods_finite_start",
    )
  end

  def down
    # Validation is monotonic; the preceding additive migration owns constraint removal.
  end
end
