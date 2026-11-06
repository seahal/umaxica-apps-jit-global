# frozen_string_literal: true

class CreateClientSensitiveAdmissionSessions < ActiveRecord::Migration[8.2]
  def change
    create_table(:client_sensitive_admission_sessions) do |t|
      t.bigint(:sensitive_admission_id, null: false)
      t.string(:sid_digest, null: false, limit: 64)
      t.string(:phase, null: false, limit: 16)
      t.string(:status, null: false, limit: 16)
      t.timestamptz(:expires_at, null: false)
      t.timestamps(type: :timestamptz, null: false)
    end
    add_index(:client_sensitive_admission_sessions, :sid_digest, unique: true, name: "idx_client_sensitive_session_digest")
    add_index(:client_sensitive_admission_sessions, %i(sensitive_admission_id phase), unique: true, name: "idx_client_sensitive_session_phase")
    add_check_constraint(:client_sensitive_admission_sessions, "sid_digest ~ '^[0-9a-f]{64}$' AND phase IN ('attached', 'admitted') AND status IN ('active', 'revoked')", name: "client_sensitive_session_state")
    add_check_constraint(:client_sensitive_admission_sessions, "expires_at > created_at", name: "client_sensitive_session_deadline")
    add_foreign_key(:client_sensitive_admission_sessions, :client_sensitive_admissions, column: :sensitive_admission_id, validate: false)
  end
end
