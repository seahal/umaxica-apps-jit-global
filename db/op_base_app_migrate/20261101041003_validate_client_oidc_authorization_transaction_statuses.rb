# frozen_string_literal: true

class ValidateClientOidcAuthorizationTransactionStatuses < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!

  TABLE = :client_oidc_authorization_transactions

  def up
    validate_foreign_key(TABLE, name: "fk_client_oidc_authorization_transactions_status")
    validate_check_constraint(TABLE, name: "client_oidc_authorization_transaction_status_present")
    validate_check_constraint(TABLE, name: "client_oidc_authorization_transaction_status_facts")
    change_column_null(TABLE, :status_id, false)
    remove_check_constraint(TABLE, name: "client_oidc_authorization_transaction_status_present")
  end

  def down
    change_column_null(TABLE, :status_id, true)
  end
end
