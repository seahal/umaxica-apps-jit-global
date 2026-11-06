# frozen_string_literal: true

class CutOverClientOidcAuthorizationTransactionStatus < ActiveRecord::Migration[8.2]
  def up
    remove_check_constraint(:client_oidc_authorization_transactions, name: "client_oidc_auth_canceled_terminal")
    safety_assured { remove_column(:client_oidc_authorization_transactions, :status) }
  end

  def down
    safety_assured do
      add_column(:client_oidc_authorization_transactions, :status, :string)
      execute(<<~SQL.squish)
        UPDATE client_oidc_authorization_transactions
        SET status = CASE status_id
          WHEN 10 THEN 'pending'
          WHEN 20 THEN 'authenticated'
          WHEN 30 THEN 'consumed'
          WHEN 90 THEN 'canceled'
        END
      SQL
      change_column_null(:client_oidc_authorization_transactions, :status, false)
    end
    add_check_constraint(
      :client_oidc_authorization_transactions,
      "(canceled_at IS NULL) = (status <> 'canceled')",
      name: "client_oidc_auth_canceled_terminal",
    )
  end
end
