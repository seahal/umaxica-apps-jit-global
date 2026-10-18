# frozen_string_literal: true

class BindVisitorVerifiedStepUpCredential < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!
  public

  def change
    add_column(:visitor_step_up_ceremony_transactions, :verified_credential_ref, :string)
    add_check_constraint(
      :visitor_step_up_ceremony_transactions,
      "status <> 'verified' OR (verified_credential_ref IS NOT NULL AND length(verified_credential_ref) > 0)",
      name: "visitor_step_up_verified_credential_present", validate: false,
    )
    validate_check_constraint(
      :visitor_step_up_ceremony_transactions,
      name: "visitor_step_up_verified_credential_present",
    )
  end
end
