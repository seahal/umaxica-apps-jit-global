# frozen_string_literal: true

class AddOidcFreshnessOptionsToOperatorAuthorizationTransactions < ActiveRecord::Migration[8.0]
  def change
    add_column(:operator_oidc_authorization_transactions, :oidc_prompt, :string)
    add_column(:operator_oidc_authorization_transactions, :oidc_max_age, :integer)
  end
end
