# frozen_string_literal: true

class ValidateClientSensitiveAdmissionForeignKeys < ActiveRecord::Migration[8.2]
  def up
    validate_foreign_key(:client_sensitive_admission_attachments, :client_sensitive_admissions)
    validate_foreign_key(:client_sensitive_admission_confirmations, :client_sensitive_admissions)
    validate_foreign_key(:client_sensitive_admission_redemptions, :client_sensitive_admissions)
  end

  # Validation is monotonic; rollback retains the stronger constraint.
  def down
  end
end
