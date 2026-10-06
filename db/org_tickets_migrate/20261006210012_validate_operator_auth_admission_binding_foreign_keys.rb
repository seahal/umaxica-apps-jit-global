# typed: false
# frozen_string_literal: true

class ValidateOperatorAuthAdmissionBindingForeignKeys < ActiveRecord::Migration[8.2]
  def change
    validate_foreign_key :operator_auth_admission_bindings, :operator_sign_in_flows
    validate_foreign_key :operator_auth_admission_bindings, :operator_oidc_authorization_transactions
    validate_foreign_key :operator_auth_admission_bindings, :operator_step_up_ceremony_transactions
    validate_foreign_key :operator_auth_admission_bindings, :operator_tokens
    validate_foreign_key :operator_auth_admission_bindings, :operator_auth_ceremony_sessions
    validate_foreign_key :operator_auth_admission_bindings, :operator_auth_ceremony_sessions,
                         name: "fk_operator_auth_admission_bindings_admitted_session"
  end
end
