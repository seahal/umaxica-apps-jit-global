# frozen_string_literal: true

class ValidateOperatorSensitiveAdmissionAccountingForeignKeys < ActiveRecord::Migration[8.2]
  def up
    validate_foreign_key(:operator_sensitive_admission_audit_outboxes, :operator_step_up_audit_outbox_delivery_states)
    validate_foreign_key(:operator_sensitive_admission_audit_attempts, :operator_sensitive_admission_audit_outboxes)
  end

  # Validation is monotonic; rollback retains the stronger constraint.
  def down
  end
end
