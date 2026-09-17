# frozen_string_literal: true

class AddOidcFreshnessOptionsToVisitorAuthorizationTransactions < ActiveRecord::Migration[8.0]
  def change
    add_column(:visitor_oidc_authorization_transactions, :oidc_prompt, :string)
    add_column(:visitor_oidc_authorization_transactions, :oidc_max_age, :integer)
  end
end
