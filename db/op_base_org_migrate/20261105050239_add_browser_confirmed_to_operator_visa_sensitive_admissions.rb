# frozen_string_literal: true

class AddBrowserConfirmedToOperatorVisaSensitiveAdmissions < ActiveRecord::Migration[8.2]
  def change
    remove_check_constraint(
      :operator_visa_sensitive_admissions, name: "operator_visa_admission_status",
    )
    add_check_constraint(
      :operator_visa_sensitive_admissions,
      "status IN ('issued', 'browser_confirmed', 'source_committed', 'refused', 'cancelled')",
      name: "operator_visa_admission_status",
      validate: false,
    )
  end
end
