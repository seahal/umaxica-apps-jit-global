# frozen_string_literal: true

class EnforceClientOidcAuthorizationTransactionStatuses < ActiveRecord::Migration[8.2]
  TABLE = :client_oidc_authorization_transactions
  STATUS_FACTS = <<~SQL.squish.freeze
    (status_id = 10 AND authenticated_at IS NULL AND consumed_at IS NULL AND canceled_at IS NULL AND
      base_finalized_at IS NULL AND browser_session_ref IS NULL) OR
    (status_id = 20 AND authenticated_at IS NOT NULL AND consumed_at IS NULL AND canceled_at IS NULL AND
      base_finalized_at IS NULL AND browser_session_ref IS NULL) OR
    (status_id = 30 AND authenticated_at IS NOT NULL AND consumed_at IS NOT NULL AND canceled_at IS NULL AND
      ((base_finalized_at IS NULL AND browser_session_ref IS NULL) OR
       (base_finalized_at IS NOT NULL AND browser_session_ref IS NOT NULL))) OR
    (status_id = 90 AND canceled_at IS NOT NULL AND consumed_at IS NULL AND
      base_finalized_at IS NULL AND browser_session_ref IS NULL)
  SQL

  def up
    add_check_constraint(
      TABLE, "status_id IS NOT NULL",
      name: "client_oidc_authorization_transaction_status_present", validate: false,
    )
    add_foreign_key(
      TABLE, :client_oidc_authorization_transaction_statuses,
      column: :status_id, name: "fk_client_oidc_authorization_transactions_status", on_delete: :restrict,
      validate: false,
    )
    add_check_constraint(TABLE, STATUS_FACTS, name: "client_oidc_authorization_transaction_status_facts", validate: false)
  end

  def down
    remove_check_constraint(TABLE, name: "client_oidc_authorization_transaction_status_facts")
    remove_foreign_key(TABLE, name: "fk_client_oidc_authorization_transactions_status")
    remove_check_constraint(TABLE, name: "client_oidc_authorization_transaction_status_present")
  end
end
