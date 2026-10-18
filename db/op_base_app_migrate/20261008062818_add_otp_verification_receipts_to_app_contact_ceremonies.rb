# frozen_string_literal: true

class AddOtpVerificationReceiptsToAppContactCeremonies < ActiveRecord::Migration[8.2]
  def change
    add_column(:client_email_ceremony_transactions, :otp_receipt_verifier, :string)
    add_column(:client_email_ceremony_transactions, :otp_result_expires_at, :datetime)
    add_check_constraint(:client_email_ceremony_transactions, <<~SQL.squish, name: "client_email_otp_receipt_bounds", validate: false)
      (otp_receipt_verifier IS NULL AND otp_result_expires_at IS NULL) OR
      (otp_receipt_verifier IS NOT NULL AND otp_receipt_verifier ~ '^[0-9a-f]{64}$' AND
       otp_consumed_at IS NOT NULL AND otp_cancelled_at IS NULL AND otp_verifier IS NULL AND
       otp_result_expires_at IS NOT NULL AND isfinite(otp_result_expires_at) AND
       otp_result_expires_at > otp_consumed_at AND
       otp_result_expires_at <= otp_consumed_at + interval '60 seconds' AND
       otp_result_expires_at <= expires_at)
    SQL
    add_column(:client_telephone_ceremony_transactions, :otp_receipt_verifier, :string)
    add_column(:client_telephone_ceremony_transactions, :otp_result_expires_at, :datetime)
    add_check_constraint(:client_telephone_ceremony_transactions, <<~SQL.squish, name: "client_telephone_otp_receipt_bounds", validate: false)
      (otp_receipt_verifier IS NULL AND otp_result_expires_at IS NULL) OR
      (otp_receipt_verifier IS NOT NULL AND otp_receipt_verifier ~ '^[0-9a-f]{64}$' AND
       otp_consumed_at IS NOT NULL AND otp_cancelled_at IS NULL AND otp_verifier IS NULL AND
       otp_result_expires_at IS NOT NULL AND isfinite(otp_result_expires_at) AND
       otp_result_expires_at > otp_consumed_at AND
       otp_result_expires_at <= otp_consumed_at + interval '60 seconds' AND
       otp_result_expires_at <= expires_at)
    SQL
  end
end
