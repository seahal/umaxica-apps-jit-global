# frozen_string_literal: true

class CreateOperatorVisaSensitiveAdmissions < ActiveRecord::Migration[8.2]
  def change
    create_table(:operator_visa_sensitive_admissions) do |t|
      t.string(:public_ref, null: false, limit: 21)
      t.bigint(:oidc_authorization_transaction_id, null: false)
      t.bigint(:step_up_ceremony_transaction_id, null: false)
      t.bigint(:auth_admission_binding_id, null: false)
      t.string(:realm, null: false, limit: 3)
      t.string(:client_id, null: false, limit: 64)
      t.string(:actor_subject, null: false, limit: 255)
      t.string(:grant_sid, null: false, limit: 64)
      t.string(:rp_session_ref, null: false, limit: 64)
      t.timestamptz(:rp_session_expires_at, null: false)
      t.string(:browser_binding_digest, null: false, limit: 64)
      t.string(:purpose, null: false, limit: 32)
      t.string(:provider, null: false, limit: 16)
      t.string(:event_jti, null: false, limit: 255)
      t.bigint(:event_auth_time, null: false)
      t.string(:event_acr, null: false, limit: 64)
      t.jsonb(:event_amr, null: false)
      t.string(:status, null: false, limit: 24)
      t.timestamptz(:expires_at, null: false)
      t.timestamps(type: :timestamptz, null: false)
    end

    add_index(:operator_visa_sensitive_admissions, :public_ref, unique: true,
              name: "idx_operator_visa_admission_ref")
    add_index(:operator_visa_sensitive_admissions, :oidc_authorization_transaction_id, unique: true,
              name: "idx_operator_visa_admission_oidc")
    add_index(:operator_visa_sensitive_admissions, :step_up_ceremony_transaction_id, unique: true,
              name: "idx_operator_visa_admission_ticket")
    add_index(:operator_visa_sensitive_admissions, :auth_admission_binding_id, unique: true,
              name: "idx_operator_visa_admission_binding")
    add_index(:operator_visa_sensitive_admissions, %i(rp_session_ref status),
              name: "idx_operator_visa_admission_rp_session")
    add_check_constraint(:operator_visa_sensitive_admissions,
                         "realm = 'org' AND client_id = 'base-org-ww'", name: "operator_visa_admission_realm")
    add_check_constraint(:operator_visa_sensitive_admissions,
                         "purpose = 'passkey_registration' AND provider = 'none'",
                         name: "operator_visa_admission_purpose")
    add_check_constraint(:operator_visa_sensitive_admissions,
                         "status IN ('issued', 'source_committed', 'refused', 'cancelled')",
                         name: "operator_visa_admission_status")
    add_check_constraint(:operator_visa_sensitive_admissions,
                         "public_ref ~ '^[A-Za-z0-9_-]{21}$' AND event_auth_time > 0 AND " \
                         "event_acr <> '' AND browser_binding_digest ~ '^[0-9a-f]{64}$' AND " \
                         "jsonb_typeof(event_amr) = 'array' AND jsonb_array_length(event_amr) > 0 AND " \
                         "expires_at > created_at AND expires_at <= rp_session_expires_at",
                         name: "operator_visa_admission_values")
    add_foreign_key(:operator_visa_sensitive_admissions, :operator_oidc_authorization_transactions,
                    column: :oidc_authorization_transaction_id, on_delete: :restrict, validate: false)
    add_foreign_key(:operator_visa_sensitive_admissions, :operator_step_up_ceremony_transactions,
                    column: :step_up_ceremony_transaction_id, on_delete: :restrict, validate: false)
    add_foreign_key(:operator_visa_sensitive_admissions, :operator_auth_admission_bindings,
                    column: :auth_admission_binding_id, on_delete: :restrict, validate: false)
  end
end
