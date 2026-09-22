# frozen_string_literal: true

class MakeTotpFailuresTerminal < ActiveRecord::Migration[8.2]
  def change
    safety_assured do
      remove_column(:client_totp_credentials, :otp_attempt_window_started_at, :datetime)
      remove_column(:client_totp_credentials, :locked_at, :datetime)
    end

    add_check_constraint(
      :client_totp_credentials,
      "otp_attempts_count >= 0 AND otp_attempts_count <= 100",
      name: "client_totp_credentials_otp_attempts_count_range",
      validate: false,
    )
    change_column_default(
      :client_totp_credentials,
      :user_identity_totp_credential_status_id,
      from: 0,
      to: 5,
    )
  end
end
