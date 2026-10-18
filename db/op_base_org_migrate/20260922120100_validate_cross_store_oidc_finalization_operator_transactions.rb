# typed: false
# frozen_string_literal: true

class ValidateCrossStoreOidcFinalizationOperatorTransactions < ActiveRecord::Migration[8.0]
  def change
    validate_check_constraint(
      :operator_oidc_authorization_transactions,
      name: "operator_oidc_auth_transactions_result_generation_nonnegative",
    )
  end
end
