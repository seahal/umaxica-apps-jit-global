# frozen_string_literal: true

class AddOtpLastSentAtToVisitorTelephones < ActiveRecord::Migration[8.2]
  public

  def change
    add_column(:visitor_telephones, :otp_last_sent_at, :datetime)
  end
end
