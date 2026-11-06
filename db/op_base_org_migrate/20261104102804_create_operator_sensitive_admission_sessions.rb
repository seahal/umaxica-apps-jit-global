# frozen_string_literal: true

class CreateOperatorSensitiveAdmissionSessions < ActiveRecord::Migration[8.2]
  def change
    create_table(:operator_sensitive_admission_sessions) do |t|
      t.bigint(:sensitive_admission_id, null: false)
      t.string(:sid_digest, null: false, limit: 64)
      t.string(:phase, null: false, limit: 16)
      t.string(:status, null: false, limit: 16)
      t.timestamptz(:expires_at, null: false)
      t.timestamps(type: :timestamptz, null: false)
    end
    add_index(:operator_sensitive_admission_sessions, :sid_digest, unique: true, name: "idx_operator_sensitive_session_digest")
    add_index(:operator_sensitive_admission_sessions, %i(sensitive_admission_id phase), unique: true, name: "idx_operator_sensitive_session_phase")
    add_check_constraint(:operator_sensitive_admission_sessions, "sid_digest ~ '^[0-9a-f]{64}$' AND phase IN ('attached', 'admitted') AND status IN ('active', 'revoked')", name: "operator_sensitive_session_state")
    add_check_constraint(:operator_sensitive_admission_sessions, "expires_at > created_at", name: "operator_sensitive_session_deadline")
    add_foreign_key(:operator_sensitive_admission_sessions, :operator_sensitive_admissions, column: :sensitive_admission_id, validate: false)
  end
end
