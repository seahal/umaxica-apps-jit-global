# frozen_string_literal: true

# WU-30 (D-88, D-92, D-168; adr/authentication-security-mode.md A1-A3): Security Mode replaces
# the MFA level. Valid modes are NORMAL=3 and ADVANCED=7 only.
class CreateVisitorSecurityModes < ActiveRecord::Migration[8.2]
  def change
    create_table(:visitor_security_modes, id: false) do |t|
      t.bigint(:id, null: false, primary_key: true)
    end
    add_check_constraint(:visitor_security_modes, "id IN (3, 7)", name: "chk_visitor_security_modes_id")
    add_column(:visitors, :security_mode_id, :bigint)
    add_foreign_key(:visitors, :visitor_security_modes, column: :security_mode_id, validate: false)
  end
end
