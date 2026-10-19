# frozen_string_literal: true

# D09: a user Cancel on the first Sign In/Up page ends the parent authorization transaction with a
# `canceled` status. The encrypted single-use handoff that carries the Cancel from Auth to Base is
# stored the same way as the Step-Up cancellation handoff.
class AddCancellationToClientOidcAuthorizationTransactions < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!

  public

  def change
    table = :client_oidc_authorization_transactions
    add_column(table, :canceled_at, :timestamptz)
    add_column(table, :cancellation_handoff_digest, :string, limit: 64)
    add_column(table, :cancellation_handoff_ref, :uuid)
    add_column(table, :cancellation_handoff_ciphertext, :text)
    add_index(table, :cancellation_handoff_digest, unique: true, algorithm: :concurrently)
    add_index(table, :cancellation_handoff_ref, unique: true, algorithm: :concurrently)
    add_check_constraint(
      table, "cancellation_handoff_digest IS NULL OR cancellation_handoff_digest ~ '^[0-9a-f]{64}$'",
      name: "client_oidc_auth_cancellation_handoff_valid", validate: false,
    )
    add_check_constraint(
      table,
      "(cancellation_handoff_ref IS NULL AND cancellation_handoff_ciphertext IS NULL) OR " \
      "(cancellation_handoff_ref IS NOT NULL AND cancellation_handoff_ciphertext IS NOT NULL)",
      name: "client_oidc_auth_cancellation_handoff_pair", validate: false,
    )
    add_check_constraint(
      table, "(canceled_at IS NULL) = (status <> 'canceled')",
      name: "client_oidc_auth_canceled_terminal", validate: false,
    )
    validate_check_constraint(table, name: "client_oidc_auth_cancellation_handoff_valid")
    validate_check_constraint(table, name: "client_oidc_auth_cancellation_handoff_pair")
    validate_check_constraint(table, name: "client_oidc_auth_canceled_terminal")
  end
end
