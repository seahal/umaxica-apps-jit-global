# frozen_string_literal: true

class CreateClientTotpRegistrationReceipts < ActiveRecord::Migration[8.2]
  def change
    create_table(:client_totp_registration_receipts) do |t|
    end
  end
end
