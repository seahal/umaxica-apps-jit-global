# frozen_string_literal: true

class ValidateClientSensitiveAdmissionAccountingForeignKeys < ActiveRecord::Migration[8.2]
  def up
    validate_foreign_key(:client_sensitive_admission_audit_outboxes, :client_step_up_audit_outbox_delivery_states)
    validate_foreign_key(:client_sensitive_admission_audit_attempts, :client_sensitive_admission_audit_outboxes)
  end

  # Validation is monotonic; rollback retains the stronger constraint.
  def down
  end
end
