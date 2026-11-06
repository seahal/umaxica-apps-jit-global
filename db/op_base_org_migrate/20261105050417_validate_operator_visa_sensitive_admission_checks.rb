# frozen_string_literal: true

class ValidateOperatorVisaSensitiveAdmissionChecks < ActiveRecord::Migration[8.2]
  def change
    validate_check_constraint(
      :operator_visa_sensitive_admissions, name: "operator_visa_admission_status",
    )
  end
end
