# frozen_string_literal: true

class CreateClientVisaSocialLinkAdmissions < ActiveRecord::Migration[8.2]
  def change
    create_table(:client_visa_social_link_admissions, id: :bigserial) do |t|
      t.string(:public_ref, null: false, limit: 21)
      t.bigint(:oidc_authorization_transaction_id, null: false)
      t.bigint(:social_ceremony_transaction_id, null: false)
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

    add_index(:client_visa_social_link_admissions, :public_ref, unique: true,
              name: "idx_client_visa_social_admission_ref")
    add_index(:client_visa_social_link_admissions, :oidc_authorization_transaction_id, unique: true,
              name: "idx_client_visa_social_admission_oidc")
    add_index(:client_visa_social_link_admissions, :social_ceremony_transaction_id, unique: true,
              name: "idx_client_visa_social_admission_social_tx")
    add_index(:client_visa_social_link_admissions, :step_up_ceremony_transaction_id, unique: true,
              name: "idx_client_visa_social_admission_ticket")
    add_index(:client_visa_social_link_admissions, :auth_admission_binding_id, unique: true,
              name: "idx_client_visa_social_admission_binding")
    add_index(:client_visa_social_link_admissions, %i(rp_session_ref status),
              name: "idx_client_visa_social_admission_rp_session")
    add_check_constraint(:client_visa_social_link_admissions,
                         "realm = 'app' AND client_id = 'base-app-ww'",
                         name: "client_visa_social_admission_realm")
    add_check_constraint(:client_visa_social_link_admissions,
                         "purpose = 'social_link' AND provider IN ('google', 'apple')",
                         name: "client_visa_social_admission_purpose")
    add_check_constraint(:client_visa_social_link_admissions,
                         "status IN ('issued', 'browser_confirmed', 'source_committed', 'refused', 'cancelled')",
                         name: "client_visa_social_admission_status")
    add_check_constraint(:client_visa_social_link_admissions,
                         "public_ref ~ '^[A-Za-z0-9_-]{21}$' AND event_auth_time > 0 AND " \
                         "event_acr <> '' AND browser_binding_digest ~ '^[0-9a-f]{64}$' AND " \
                         "jsonb_typeof(event_amr) = 'array' AND jsonb_array_length(event_amr) > 0 AND " \
                         "expires_at > created_at AND expires_at <= rp_session_expires_at",
                         name: "client_visa_social_admission_values")
    add_foreign_key(:client_visa_social_link_admissions, :client_oidc_authorization_transactions,
                    column: :oidc_authorization_transaction_id, on_delete: :restrict, validate: false)
    add_foreign_key(:client_visa_social_link_admissions, :client_social_ceremony_transactions,
                    column: :social_ceremony_transaction_id, on_delete: :restrict, validate: false)
    add_foreign_key(:client_visa_social_link_admissions, :client_step_up_ceremony_transactions,
                    column: :step_up_ceremony_transaction_id, on_delete: :restrict, validate: false)
    add_foreign_key(:client_visa_social_link_admissions, :client_auth_admission_bindings,
                    column: :auth_admission_binding_id, on_delete: :restrict, validate: false)
  end
end
