# frozen_string_literal: true

class ValidateOperatorSensitiveAdmissionForeignKeys < ActiveRecord::Migration[8.2]
  def up
    validate_foreign_key(:operator_sensitive_admission_attachments, :operator_sensitive_admissions)
    validate_foreign_key(:operator_sensitive_admission_confirmations, :operator_sensitive_admissions)
    validate_foreign_key(:operator_sensitive_admission_redemptions, :operator_sensitive_admissions)
  end

  # Validation is monotonic; rollback retains the stronger constraint.
  def down
  end
end
