# frozen_string_literal: true

class AddEmailOtpContextToVisitorAuthCeremonySessions < ActiveRecord::Migration[8.2]
  def change
    add_column(:visitor_auth_ceremony_sessions, :email_otp_context, :jsonb)
  end
end
