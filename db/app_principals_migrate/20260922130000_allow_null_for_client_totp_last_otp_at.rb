# frozen_string_literal: true

class AllowNullForClientTotpLastOtpAt < ActiveRecord::Migration[8.2]
  def up
    safety_assured do
      change_column_default(:client_totp_credentials, :last_otp_at, from: -Float::INFINITY, to: nil)
      change_column_null(:client_totp_credentials, :last_otp_at, true)

      execute(<<~SQL.squish)
        UPDATE client_totp_credentials
        SET last_otp_at = NULL
        WHERE last_otp_at = '-infinity'::timestamp
      SQL
    end
  end

  def down
    safety_assured do
      execute(<<~SQL.squish)
        UPDATE client_totp_credentials
        SET last_otp_at = '-infinity'::timestamp
        WHERE last_otp_at IS NULL
      SQL

      change_column_null(:client_totp_credentials, :last_otp_at, false, -Float::INFINITY)
      change_column_default(:client_totp_credentials, :last_otp_at, from: nil, to: -Float::INFINITY)
    end
  end
end
