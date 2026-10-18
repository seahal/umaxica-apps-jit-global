# frozen_string_literal: true

# TOTP retry protection is authenticator state and must survive a rate-limit store outage or
# flush, so it lives in PostgreSQL next to the credential it protects. The column names and the
# "-infinity" sentinel follow OtpLockable (the email/SMS OTP lockout): `locked_at` holds the
# instant the lockout ends, and "-infinity" means not locked.
class AddTotpAttemptLockToClientTotpCredentials < ActiveRecord::Migration[8.2]
  def change
    add_column(:client_totp_credentials, :otp_attempts_count, :integer, default: 0, null: false)
    add_column(
      :client_totp_credentials, :otp_attempt_window_started_at, :datetime,
      default: -Float::INFINITY, null: false,
    )
    add_column(:client_totp_credentials, :locked_at, :datetime, default: -Float::INFINITY, null: false)
  end
end
