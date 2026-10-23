# frozen_string_literal: true

# WU-17: every root and grant records the authentication epoch it was issued under (no default).
# The checks are added unvalidated here and validated in the next migration.
class RequireAuthenticationEpochOpBaseOrg < ActiveRecord::Migration[8.2]
  TABLES = %i(operator_tokens op_org_grants).freeze

  def up
    TABLES.each do |table|
      remove_check_constraint(table, name: "chk_#{table}_authentication_epoch")
      add_check_constraint(
        table, "authentication_epoch >= 0", name: "chk_#{table}_authentication_epoch", validate: false,
      )
      add_check_constraint(
        table, "authentication_epoch IS NOT NULL", name: "chk_#{table}_authentication_epoch_nn", validate: false,
      )
    end
  end

  def down
    TABLES.each do |table|
      remove_check_constraint(table, name: "chk_#{table}_authentication_epoch_nn")
      remove_check_constraint(table, name: "chk_#{table}_authentication_epoch")
      add_check_constraint(
        table, "authentication_epoch IS NULL OR authentication_epoch >= 0",
        name: "chk_#{table}_authentication_epoch", validate: false,
      )
    end
  end
end
