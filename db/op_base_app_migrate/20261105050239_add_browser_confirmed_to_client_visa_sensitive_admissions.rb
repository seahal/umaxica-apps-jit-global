# frozen_string_literal: true

class AddBrowserConfirmedToClientVisaSensitiveAdmissions < ActiveRecord::Migration[8.2]
  def change
    remove_check_constraint(
      :client_visa_sensitive_admissions, name: "client_visa_admission_status",
    )
    remove_check_constraint(
      :client_visa_sensitive_admissions, name: "client_visa_admission_purpose",
    )
    add_check_constraint(
      :client_visa_sensitive_admissions,
      "status IN ('issued', 'browser_confirmed', 'source_committed', 'refused', 'cancelled')",
      name: "client_visa_admission_status",
      validate: false,
    )
    add_check_constraint(
      :client_visa_sensitive_admissions,
      "purpose = 'passkey_registration' AND provider = 'none'",
      name: "client_visa_admission_purpose",
      validate: false,
    )
  end
end
