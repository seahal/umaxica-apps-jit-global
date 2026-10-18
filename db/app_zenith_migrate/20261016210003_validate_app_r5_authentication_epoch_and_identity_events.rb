# typed: false
# frozen_string_literal: true

class ValidateAppR5AuthenticationEpochAndIdentityEvents < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!

  def up
    validate_check_constraint(:clients, name: "chk_clients_authentication_epoch_nonnegative")
    validate_check_constraint(:identity_authentication_events, name: "chk_app_identity_authentication_events_realm")
    validate_check_constraint(:identity_authentication_events, name: "chk_app_identity_authentication_events_epoch_nonnegative")
  end

  def down
    raise ActiveRecord::IrreversibleMigration, "authentication epoch constraints are forward-only"
  end
end
