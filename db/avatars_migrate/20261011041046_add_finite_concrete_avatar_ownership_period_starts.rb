# frozen_string_literal: true

class AddFiniteConcreteAvatarOwnershipPeriodStarts < ActiveRecord::Migration[8.2]
  def change
    add_check_constraint(
      :avatar_enterprise_ownership_periods,
      "isfinite(valid_from)",
      name: "chk_avatar_enterprise_ownership_periods_finite_start",
      validate: false,
    )
    add_check_constraint(
      :avatar_bureau_ownership_periods,
      "isfinite(valid_from)",
      name: "chk_avatar_bureau_ownership_periods_finite_start",
      validate: false,
    )
  end
end
