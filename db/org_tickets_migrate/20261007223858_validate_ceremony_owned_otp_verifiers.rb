# frozen_string_literal: true

class ValidateCeremonyOwnedOtpVerifiers < ActiveRecord::Migration[8.2]
  public

  def change
    %i(operator_email_ceremony_transactions operator_telephone_ceremony_transactions).each do |table|
      validate_check_constraint table, name: "#{table}_otp_purpose"
      validate_check_constraint table, name: "#{table}_otp_material"
    end
  end
end
