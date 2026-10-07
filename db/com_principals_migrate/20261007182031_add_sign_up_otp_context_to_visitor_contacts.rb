# frozen_string_literal: true

class AddSignUpOtpContextToVisitorContacts < ActiveRecord::Migration[8.2]
  def change
    add_column(:visitor_emails, :sign_up_otp_context, :jsonb)
    add_column(:visitor_telephones, :sign_up_otp_context, :jsonb)
  end
end
