# frozen_string_literal: true

class ValidateClientSensitiveAdmissionSessionForeignKey < ActiveRecord::Migration[8.2]
  def up
    validate_foreign_key(:client_sensitive_admission_sessions, :client_sensitive_admissions)
  end

  # Validation is monotonic; rollback retains the stronger constraint.
  def down
  end
end
