# frozen_string_literal: true

class ValidateAppContactCeremonyOtpReceipts < ActiveRecord::Migration[8.2]
  def change
    reversible do |direction|
      direction.up do
        validate_check_constraint(:client_email_ceremony_transactions, name: "client_email_otp_receipt_bounds")
        validate_check_constraint(:client_telephone_ceremony_transactions, name: "client_telephone_otp_receipt_bounds")
      end
      # PostgreSQL cannot demote validation; the preceding additive migration owns constraint removal.
    end
  end
end
