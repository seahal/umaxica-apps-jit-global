# frozen_string_literal: true

class ValidateConcreteAvatarOwnershipPeriodConstraints < ActiveRecord::Migration[8.2]
  def up
    validate_check_constraint(
      :avatar_enterprise_ownership_periods,
      name: "chk_avatar_enterprise_ownership_periods_strict_interval",
    )
    validate_check_constraint(
      :avatar_bureau_ownership_periods,
      name: "chk_avatar_bureau_ownership_periods_strict_interval",
    )
  end

  def down
    # Constraint validation is monotonic; the table and constraint migration owns removal.
  end
end
