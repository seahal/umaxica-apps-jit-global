# frozen_string_literal: true

class ValidateTotpFailureCount < ActiveRecord::Migration[8.2]
  def change
    validate_check_constraint(
      :client_totp_credentials,
      name: "client_totp_credentials_otp_attempts_count_range",
    )
  end
end
