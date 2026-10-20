# frozen_string_literal: true

class ValidateComZenithNumericalityChecks < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!

  def change
    validate_check_constraint(:visitor_passkeys, name: "chk_visitor_passkeys_sign_count")
    validate_check_constraint(:visitor_secret_credential_kinds, name: "chk_visitor_secret_credential_kinds_id")
  end
end
