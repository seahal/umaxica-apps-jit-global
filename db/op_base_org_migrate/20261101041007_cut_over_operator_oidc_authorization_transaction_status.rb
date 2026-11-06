# frozen_string_literal: true

class CutOverOperatorOidcAuthorizationTransactionStatus < ActiveRecord::Migration[8.2]
  def up
    remove_check_constraint(:operator_oidc_authorization_transactions, name: "operator_oidc_auth_canceled_terminal")
    safety_assured { remove_column(:operator_oidc_authorization_transactions, :status) }
  end

  def down
    safety_assured do
      add_column(:operator_oidc_authorization_transactions, :status, :string)
      execute(<<~SQL.squish)
        UPDATE operator_oidc_authorization_transactions
        SET status = CASE status_id
          WHEN 10 THEN 'pending'
          WHEN 20 THEN 'authenticated'
          WHEN 30 THEN 'consumed'
          WHEN 90 THEN 'canceled'
        END
      SQL
      change_column_null(:operator_oidc_authorization_transactions, :status, false)
    end
    add_check_constraint(
      :operator_oidc_authorization_transactions,
      "(canceled_at IS NULL) = (status <> 'canceled')",
      name: "operator_oidc_auth_canceled_terminal",
    )
  end
end
