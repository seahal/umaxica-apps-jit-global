# frozen_string_literal: true

class ValidateOperatorVisaSensitiveAdmissionForeignKeys < ActiveRecord::Migration[8.2]
  def change
    validate_foreign_key(:operator_visa_sensitive_admissions, :operator_oidc_authorization_transactions)
    validate_foreign_key(:operator_visa_sensitive_admissions, :operator_step_up_ceremony_transactions)
    validate_foreign_key(:operator_visa_sensitive_admissions, :operator_auth_admission_bindings)
  end
end
