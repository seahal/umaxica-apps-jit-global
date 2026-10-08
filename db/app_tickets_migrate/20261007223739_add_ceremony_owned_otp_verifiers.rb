# frozen_string_literal: true

class AddCeremonyOwnedOtpVerifiers < ActiveRecord::Migration[8.2]
  public

  def change
    %i(client_email_ceremony_transactions client_telephone_ceremony_transactions).each do |table|
      add_column(table, :purpose, :string)
      add_column(table, :otp_generation, :uuid)
      add_column(table, :otp_verifier, :string)
      add_column(table, :otp_expires_at, :datetime)
      add_column(table, :otp_consumed_at, :datetime)
      add_column(table, :otp_cancelled_at, :datetime)
      add_check_constraint(
        table,
        "purpose IS NULL OR purpose IN ('sign_up', 'sign_in', 'recovery', 'withdrawal', 'credential_registration')",
        name: "#{table}_otp_purpose", validate: false,
      )
      add_check_constraint(
        table,
        "otp_verifier IS NULL OR (purpose IS NOT NULL AND otp_generation IS NOT NULL AND otp_expires_at IS NOT NULL)",
        name: "#{table}_otp_material", validate: false,
      )
    end
  end
end
