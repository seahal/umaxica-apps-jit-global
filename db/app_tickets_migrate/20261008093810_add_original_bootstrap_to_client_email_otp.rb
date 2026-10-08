# frozen_string_literal: true

class AddOriginalBootstrapToClientEmailOtp < ActiveRecord::Migration[8.2]
  public

  def change
    add_column(:client_email_ceremony_transactions, :bootstrap_ceremony_transaction_ref, :string)
    add_foreign_key(
      :client_email_ceremony_transactions, :client_step_up_ceremony_transactions,
      column: :bootstrap_ceremony_transaction_ref, primary_key: :transaction_id,
      name: "client_email_otp_original_bootstrap_fk", validate: false,
    )
    add_check_constraint(
      :client_email_ceremony_transactions,
      "bootstrap_ceremony_transaction_ref IS NULL OR " \
      "(operation = 'registration' AND purpose IS NOT NULL AND purpose = 'credential_registration')",
      name: "client_email_otp_bootstrap_purpose", validate: false,
    )
  end
end
