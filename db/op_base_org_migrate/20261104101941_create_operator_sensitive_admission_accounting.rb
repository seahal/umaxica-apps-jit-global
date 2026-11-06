# frozen_string_literal: true

class CreateOperatorSensitiveAdmissionAccounting < ActiveRecord::Migration[8.2]
  def change
    create_outboxes
    create_attempts
  end

  private

  def create_outboxes
    create_table(:operator_sensitive_admission_audit_outboxes) do |t|
      t.uuid(:event_uuid, null: false)
      t.string(:event_type, null: false, limit: 64)
      t.string(:realm, null: false, limit: 3)
      t.string(:client_id, null: false, limit: 64)
      t.string(:subject_ref, null: false, limit: 255)
      t.string(:context_ref, null: false, limit: 21)
      t.string(:reason_code, null: false, limit: 64)
      t.jsonb(:payload, null: false)
      t.timestamptz(:occurred_at, null: false)
      t.bigint(:delivery_state_id, null: false)
      t.timestamps(type: :timestamptz, null: false)
    end
    add_index(:operator_sensitive_admission_audit_outboxes, :event_uuid, unique: true, name: "idx_operator_sensitive_audit_uuid")
    add_index(:operator_sensitive_admission_audit_outboxes, :context_ref, unique: true, name: "idx_operator_sensitive_audit_context")
    add_index(:operator_sensitive_admission_audit_outboxes, :delivery_state_id, name: "idx_operator_sensitive_audit_delivery")
    add_check_constraint(:operator_sensitive_admission_audit_outboxes, "event_type = 'sensitive_admission.closed' AND realm = 'ORG' AND client_id = 'base-org-ww'", name: "operator_sensitive_audit_identity")
    add_check_constraint(:operator_sensitive_admission_audit_outboxes, "reason_code IN ('completed', 'expired', 'user_cancelled')", name: "operator_sensitive_audit_reason")
    add_check_constraint(:operator_sensitive_admission_audit_outboxes, "jsonb_typeof(payload) = 'object' AND payload ? 'admission_ref' AND jsonb_typeof(payload -> 'admission_ref') = 'string' AND payload - 'admission_ref' = '{}'::jsonb AND payload ->> 'admission_ref' = context_ref", name: "operator_sensitive_audit_payload")
    add_foreign_key(:operator_sensitive_admission_audit_outboxes, :operator_step_up_audit_outbox_delivery_states, column: :delivery_state_id, validate: false)
  end

  def create_attempts
    create_table(:operator_sensitive_admission_audit_attempts) do |t|
      t.bigint(:outbox_id, null: false)
      t.integer(:attempt_number, null: false)
      t.timestamptz(:attempted_at, null: false)
      t.string(:outcome, null: false, limit: 16)
      t.string(:failure_code, null: false, limit: 64)
    end
    add_index(:operator_sensitive_admission_audit_attempts, %i(outbox_id attempt_number), unique: true, name: "idx_operator_sensitive_audit_attempt_number")
    add_index(:operator_sensitive_admission_audit_attempts, :outbox_id, unique: true, where: "outcome = 'delivered'", name: "idx_operator_sensitive_audit_attempt_delivered")
    add_check_constraint(:operator_sensitive_admission_audit_attempts, "attempt_number > 0 AND outcome IN ('delivered', 'failed')", name: "operator_sensitive_attempt_outcome")
    add_check_constraint(:operator_sensitive_admission_audit_attempts, "failure_code IN ('none', 'chronicle_unavailable', 'retention_policy_missing', 'event_identity_conflict', 'chronicle_record_invalid', 'delivery_failed') AND (outcome <> 'delivered' OR failure_code = 'none')", name: "operator_sensitive_attempt_failure")
    add_foreign_key(:operator_sensitive_admission_audit_attempts, :operator_sensitive_admission_audit_outboxes, column: :outbox_id, validate: false)
  end
end
