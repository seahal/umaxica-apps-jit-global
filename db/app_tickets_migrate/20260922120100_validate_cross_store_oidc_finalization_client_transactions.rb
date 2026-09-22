# typed: false
# frozen_string_literal: true

class ValidateCrossStoreOidcFinalizationClientTransactions < ActiveRecord::Migration[8.0]
  def change
    validate_check_constraint(
      :client_oidc_authorization_transactions,
      name: "client_oidc_auth_transactions_result_generation_nonnegative",
    )
  end
end
