# frozen_string_literal: true

class AddCredentialRegistrationOtpContextToClientContacts < ActiveRecord::Migration[8.2]
  def change
    add_column(:client_emails, :credential_registration_otp_context, :jsonb)
    add_column(:client_telephones, :credential_registration_otp_context, :jsonb)
  end
end
