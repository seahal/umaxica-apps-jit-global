# frozen_string_literal: true

class ValidateClientEmailOriginalBootstrap < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!

  public

  def up
    add_index(
      :client_email_ceremony_transactions, :bootstrap_ceremony_transaction_ref,
      name: "client_email_otp_original_bootstrap", algorithm: :concurrently,
    )
    validate_foreign_key(:client_email_ceremony_transactions, name: "client_email_otp_original_bootstrap_fk")
    validate_check_constraint(:client_email_ceremony_transactions, name: "client_email_otp_bootstrap_purpose")
  end

  def down
    remove_index(
      :client_email_ceremony_transactions, name: "client_email_otp_original_bootstrap", algorithm: :concurrently,
    )
  end
end
