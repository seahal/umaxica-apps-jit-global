# frozen_string_literal: true

class ValidateBindSignUpFlowsToAdmissionsOpBaseCom < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!

  def change
    validate_foreign_key(:visitor_sign_up_flows, :visitor_auth_admission_bindings)
    add_index(
      :visitor_sign_up_flows, :auth_admission_binding_id, unique: true,
                                                          where: "status_id IN (10, 20, 30, 35, 38, 40, 60)",
                                                          algorithm: :concurrently, name: "idx_visitor_signup_one_in_progress_per_admission",
    )
  end
end
