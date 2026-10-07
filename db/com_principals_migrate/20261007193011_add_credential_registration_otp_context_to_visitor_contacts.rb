# frozen_string_literal: true

class AddCredentialRegistrationOtpContextToVisitorContacts < ActiveRecord::Migration[8.2]
  def change
    add_column(:visitor_emails, :credential_registration_otp_context, :jsonb)
    add_column(:visitor_telephones, :credential_registration_otp_context, :jsonb)
  end
end
