# typed: false
# frozen_string_literal: true

class ValidateVisitorAdmissionRedemptionConfirmation < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!

  def change
    validate_check_constraint(
      :visitor_auth_admission_bindings,
      name: "visitor_admission_bindings_redemption_requires_confirmation",
    )
  end
end
