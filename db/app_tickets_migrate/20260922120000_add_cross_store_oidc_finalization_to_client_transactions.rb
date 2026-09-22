# typed: false
# frozen_string_literal: true

class AddCrossStoreOidcFinalizationToClientTransactions < ActiveRecord::Migration[8.0]
  def change
    safety_assured do
      change_table(:client_oidc_authorization_transactions, bulk: true) do |t|
        t.integer(:result_generation, null: false, default: 0)
        t.string(:result_digest, limit: 64)
        t.datetime(:result_expires_at)
        t.datetime(:result_consumed_at)
        t.string(:browser_session_ref)
        t.datetime(:base_finalized_at)
        t.datetime(:authorization_grant_redeemed_at)
      end
    end

    add_check_constraint(
      :client_oidc_authorization_transactions,
      "result_generation >= 0",
      name: "client_oidc_auth_transactions_result_generation_nonnegative",
      validate: false,
    )
  end
end
