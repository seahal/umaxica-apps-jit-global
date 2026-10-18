# typed: false
# frozen_string_literal: true

class ValidateCrossStoreOidcFinalizationVisitorTransactions < ActiveRecord::Migration[8.0]
  def change
    validate_check_constraint(
      :visitor_oidc_authorization_transactions,
      name: "visitor_oidc_auth_transactions_result_generation_nonnegative",
    )
  end
end
