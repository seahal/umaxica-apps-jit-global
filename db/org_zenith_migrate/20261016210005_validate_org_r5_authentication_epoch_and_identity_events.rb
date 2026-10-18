# typed: false
# frozen_string_literal: true

class ValidateOrgR5AuthenticationEpochAndIdentityEvents < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!

  def up
    validate_check_constraint(:operators, name: "chk_operators_authentication_epoch_nonnegative")
    validate_check_constraint(:identity_authentication_events, name: "chk_org_identity_authentication_events_realm")
    validate_check_constraint(:identity_authentication_events, name: "chk_org_identity_authentication_events_epoch_nonnegative")
  end

  def down
    raise ActiveRecord::IrreversibleMigration, "authentication epoch constraints are forward-only"
  end
end
