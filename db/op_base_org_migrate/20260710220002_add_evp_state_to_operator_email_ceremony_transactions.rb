# typed: false
# frozen_string_literal: true

class AddEvpStateToOperatorEmailCeremonyTransactions < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!

  def change
    add_column(:operator_email_ceremony_transactions, :evp_nonce_digest, :string)
    add_column(:operator_email_ceremony_transactions, :evp_token_digest, :string)
    add_column(:operator_email_ceremony_transactions, :evp_outcome, :string)
    add_column(:operator_email_ceremony_transactions, :evp_failure_reason, :string)
    add_column(:operator_email_ceremony_transactions, :evp_issuer, :string)
    add_column(:operator_email_ceremony_transactions, :evp_issued_at, :datetime)
    add_column(:operator_email_ceremony_transactions, :evp_verified_at, :datetime)
    add_column(:operator_email_ceremony_transactions, :evp_consumed_at, :datetime)
    add_column(:operator_email_ceremony_transactions, :evp_attempt_count, :integer, null: false, default: 0)

    add_index(
      :operator_email_ceremony_transactions, :evp_nonce_digest,
      unique: true, where: "evp_nonce_digest IS NOT NULL", algorithm: :concurrently,
    )
    add_index(
      :operator_email_ceremony_transactions, :evp_token_digest,
      unique: true, where: "evp_token_digest IS NOT NULL", algorithm: :concurrently,
    )
    add_check_constraint(
      :operator_email_ceremony_transactions,
      "evp_attempt_count >= 0",
      name: :chk_operator_email_ceremony_evp_attempt_count,
      validate: false,
    )
  end
end
