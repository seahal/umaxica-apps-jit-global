# frozen_string_literal: true

class ValidateVisitorEmailOriginalBootstrap < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!

  public

  def up
    add_index(
      :visitor_email_ceremony_transactions, :bootstrap_ceremony_transaction_ref,
      name: "visitor_email_otp_original_bootstrap", algorithm: :concurrently,
    )
    validate_foreign_key(:visitor_email_ceremony_transactions, name: "visitor_email_otp_original_bootstrap_fk")
    validate_check_constraint(:visitor_email_ceremony_transactions, name: "visitor_email_otp_bootstrap_purpose")
  end

  def down
    remove_index(
      :visitor_email_ceremony_transactions, name: "visitor_email_otp_original_bootstrap", algorithm: :concurrently,
    )
  end
end
