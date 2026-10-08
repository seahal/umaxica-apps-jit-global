# frozen_string_literal: true

class AddOtpLastSentAtToClientTelephones < ActiveRecord::Migration[8.2]
  public

  def change
    add_column(:client_telephones, :otp_last_sent_at, :datetime)
  end
end
