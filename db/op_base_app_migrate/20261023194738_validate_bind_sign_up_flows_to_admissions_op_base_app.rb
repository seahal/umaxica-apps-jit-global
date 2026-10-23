# frozen_string_literal: true

class ValidateBindSignUpFlowsToAdmissionsOpBaseApp < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!

  def change
    validate_foreign_key(:client_sign_up_flows, :client_auth_admission_bindings)
    add_index(
      :client_sign_up_flows, :auth_admission_binding_id, unique: true,
                                                         where: "status_id IN (10, 20, 30, 35, 36, 38, 40, 60)",
                                                         algorithm: :concurrently, name: "idx_client_signup_one_in_progress_per_admission",
    )
  end
end
