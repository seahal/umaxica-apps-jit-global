# frozen_string_literal: true

class ValidateOperatorSensitiveAdmissionSessionForeignKey < ActiveRecord::Migration[8.2]
  def up
    validate_foreign_key(:operator_sensitive_admission_sessions, :operator_sensitive_admissions)
  end

  # Validation is monotonic; rollback retains the stronger constraint.
  def down
  end
end
