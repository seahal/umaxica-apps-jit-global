# frozen_string_literal: true

class ValidateClientVisaSensitiveAdmissionChecks < ActiveRecord::Migration[8.2]
  def change
    validate_check_constraint(
      :client_visa_sensitive_admissions, name: "client_visa_admission_status",
    )
    validate_check_constraint(
      :client_visa_sensitive_admissions, name: "client_visa_admission_purpose",
    )
  end
end
