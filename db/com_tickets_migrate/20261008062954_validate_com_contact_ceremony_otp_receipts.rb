# frozen_string_literal: true

class ValidateComContactCeremonyOtpReceipts < ActiveRecord::Migration[8.2]
  def change
    reversible do |direction|
      direction.up do
        validate_check_constraint(:visitor_email_ceremony_transactions, name: "visitor_email_otp_receipt_bounds")
        validate_check_constraint(:visitor_telephone_ceremony_transactions, name: "visitor_telephone_otp_receipt_bounds")
      end
      # PostgreSQL cannot demote validation; the preceding additive migration owns constraint removal.
    end
  end
end
