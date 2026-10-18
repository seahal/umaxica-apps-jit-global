# typed: false
# frozen_string_literal: true

class RequireOperatorAdmissionConfirmationForRedemption < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!

  def change
    add_check_constraint(
      :operator_auth_admission_bindings, "redeemed_at IS NULL OR base_confirmed_at IS NOT NULL",
      name: "operator_admission_bindings_redemption_requires_confirmation", validate: false,
    )
  end
end
