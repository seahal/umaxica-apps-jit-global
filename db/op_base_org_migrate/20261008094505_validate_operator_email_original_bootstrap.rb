# frozen_string_literal: true

class ValidateOperatorEmailOriginalBootstrap < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!

  public

  def up
    add_index(
      :operator_email_ceremony_transactions, :bootstrap_ceremony_transaction_ref,
      name: "operator_email_otp_original_bootstrap", algorithm: :concurrently,
    )
    validate_foreign_key(:operator_email_ceremony_transactions, name: "operator_email_otp_original_bootstrap_fk")
    validate_check_constraint(:operator_email_ceremony_transactions, name: "operator_email_otp_bootstrap_purpose")
  end

  def down
    remove_index(
      :operator_email_ceremony_transactions, name: "operator_email_otp_original_bootstrap", algorithm: :concurrently,
    )
  end
end
