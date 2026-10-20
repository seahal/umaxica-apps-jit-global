# frozen_string_literal: true

class ValidateOrgZenithNumericalityChecks < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!

  def change
    validate_check_constraint(:operator_passkeys, name: "chk_operator_passkeys_sign_count")
  end
end
