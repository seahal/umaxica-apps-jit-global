# frozen_string_literal: true

class ValidateAppZenithNumericalityChecks < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!

  def change
    validate_check_constraint(:client_passkeys, name: "chk_client_passkeys_sign_count")
  end
end
