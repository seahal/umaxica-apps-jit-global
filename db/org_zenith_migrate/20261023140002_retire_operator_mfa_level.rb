# frozen_string_literal: true

# WU-30: the MFA level and its legacy flag are retired; their meaning is not carried over (A1-A3,
# D-168). Recovery is rebuilding from migrations.
class RetireOperatorMfaLevel < ActiveRecord::Migration[8.2]
  def up
    add_check_constraint(:operators, "security_mode_id IS NOT NULL", name: "chk_operators_security_mode_nn", validate: false)
    safety_assured do
      remove_check_constraint(:operators, name: "chk_operators_mfa_requirement_consistency")
      remove_column(:operators, :mfa_level_id)
      remove_column(:operators, :mfa_level_enabled)
      drop_table(:operator_mfa_levels)
    end
    nil
  end

  def down
    raise ActiveRecord::IrreversibleMigration, "rebuild from migrations; D-168 accepts the loss"
  end
end
