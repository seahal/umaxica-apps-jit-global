# typed: false
# frozen_string_literal: true

class ValidateVisitorAuthAdmissionBindingForeignKeys < ActiveRecord::Migration[8.2]
  def change
    validate_foreign_key :visitor_auth_admission_bindings, :visitor_sign_in_flows
    validate_foreign_key :visitor_auth_admission_bindings, :visitor_oidc_authorization_transactions
    validate_foreign_key :visitor_auth_admission_bindings, :visitor_step_up_ceremony_transactions
    validate_foreign_key :visitor_auth_admission_bindings, :visitor_tokens
    validate_foreign_key :visitor_auth_admission_bindings, :visitor_auth_ceremony_sessions
    validate_foreign_key :visitor_auth_admission_bindings, :visitor_auth_ceremony_sessions,
                         name: "fk_visitor_auth_admission_bindings_admitted_session"
  end
end
