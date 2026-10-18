# frozen_string_literal: true

class AddSignUpOtpContextToClientContacts < ActiveRecord::Migration[8.2]
  def change
    add_column(:client_emails, :sign_up_otp_context, :jsonb)
    add_column(:client_telephones, :sign_up_otp_context, :jsonb)
  end
end
