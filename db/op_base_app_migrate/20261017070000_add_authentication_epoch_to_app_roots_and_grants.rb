# typed: false
# frozen_string_literal: true

# R5-WU06 (one.md section 6.3): an OP root and grant record the actor authentication epoch they were
# issued under, so an identity stop event with a higher cutoff epoch invalidates exactly the older
# authority and a delayed event cannot revoke a post-recovery root. NULL marks pre-R5 history.
class AddAuthenticationEpochToAppRootsAndGrants < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!

  TABLES = {
    client_tokens: "chk_client_tokens_authentication_epoch",
    op_app_grants: "chk_op_app_grants_authentication_epoch",
  }.freeze

  def up
    TABLES.each do |table, constraint|
      safety_assured { add_column(table, :authentication_epoch, :bigint) unless column_exists?(table, :authentication_epoch) }
      add_check_constraint(
        table, "authentication_epoch IS NULL OR authentication_epoch >= 0",
        name: constraint, if_not_exists: true, validate: false,
      )
      validate_check_constraint(table, name: constraint)
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration, "R5 authentication epoch facts are forward-only"
  end
end
