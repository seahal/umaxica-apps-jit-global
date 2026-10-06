# typed: false
# frozen_string_literal: true

class ValidateClientAuthAdmissionBindingForeignKeys < ActiveRecord::Migration[8.2]
  def change
    validate_foreign_key :client_auth_admission_bindings, :client_sign_in_flows
    validate_foreign_key :client_auth_admission_bindings, :client_oidc_authorization_transactions
    validate_foreign_key :client_auth_admission_bindings, :client_step_up_ceremony_transactions
    validate_foreign_key :client_auth_admission_bindings, :client_tokens
    validate_foreign_key :client_auth_admission_bindings, :client_auth_ceremony_sessions
    validate_foreign_key :client_auth_admission_bindings, :client_auth_ceremony_sessions,
                         name: "fk_client_auth_admission_bindings_admitted_session"
  end
end
