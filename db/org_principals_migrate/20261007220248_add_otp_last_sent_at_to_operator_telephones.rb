# frozen_string_literal: true

class AddOtpLastSentAtToOperatorTelephones < ActiveRecord::Migration[8.2]
  public

  def change
    add_column(:operator_telephones, :otp_last_sent_at, :datetime)
  end
end
