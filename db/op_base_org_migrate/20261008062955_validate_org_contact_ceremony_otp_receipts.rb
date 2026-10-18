# frozen_string_literal: true

class ValidateOrgContactCeremonyOtpReceipts < ActiveRecord::Migration[8.2]
  def change
    reversible do |direction|
      direction.up do
        validate_check_constraint(:operator_email_ceremony_transactions, name: "operator_email_otp_receipt_bounds")
        validate_check_constraint(:operator_telephone_ceremony_transactions, name: "operator_telephone_otp_receipt_bounds")
      end
      # PostgreSQL cannot demote validation; the preceding additive migration owns constraint removal.
    end
  end
end
