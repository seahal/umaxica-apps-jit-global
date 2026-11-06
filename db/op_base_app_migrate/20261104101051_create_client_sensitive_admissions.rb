# frozen_string_literal: true

class CreateClientSensitiveAdmissions < ActiveRecord::Migration[8.2]
  def change
    create_admission
    create_attachment
    create_confirmation
    create_redemption
  end

  private

  def create_admission
    create_table(:client_sensitive_admissions) do |t|
      t.string(:public_ref, null: false, limit: 21)
      t.string(:secret_digest, null: false, limit: 64)
      t.string(:realm, null: false, limit: 3)
      t.string(:client_id, null: false, limit: 64)
      t.string(:actor_subject, null: false, limit: 255)
      t.string(:grant_sid, null: false, limit: 64)
      t.string(:rp_session_ref, null: false, limit: 64)
      t.string(:browser_binding_digest, null: false, limit: 64)
      t.string(:purpose, null: false, limit: 32)
      t.string(:provider, null: false, limit: 16)
      t.string(:event_jti, null: false, limit: 255)
      t.bigint(:event_auth_time, null: false)
      t.timestamptz(:issued_at, null: false)
      t.timestamptz(:expires_at, null: false)
      t.string(:status, null: false, limit: 16)
      t.timestamps(type: :timestamptz, null: false)
    end
    add_index(:client_sensitive_admissions, :public_ref, unique: true)
    add_index(:client_sensitive_admissions, :secret_digest, unique: true)
    add_check_constraint(:client_sensitive_admissions, "realm = 'app' AND client_id = 'base-app-ww'", name: "client_sensitive_admission_realm")
    add_check_constraint(:client_sensitive_admissions, "(purpose = 'passkey_registration' AND provider = 'none') OR (purpose = 'social_link' AND provider IN ('google', 'apple'))", name: "client_sensitive_admission_purpose")
    add_check_constraint(:client_sensitive_admissions, "status IN ('issued', 'attached', 'confirmed', 'redeemed', 'cancelled')", name: "client_sensitive_admission_status")
    add_check_constraint(:client_sensitive_admissions, "expires_at > issued_at AND event_auth_time > 0", name: "client_sensitive_admission_deadline")
    add_check_constraint(:client_sensitive_admissions, "secret_digest ~ '^[0-9a-f]{64}$' AND browser_binding_digest ~ '^[0-9a-f]{64}$'", name: "client_sensitive_admission_digests")
    add_check_constraint(:client_sensitive_admissions, "public_ref ~ '^[A-Za-z0-9_-]{21}$' AND length(actor_subject) > 0 AND length(grant_sid) > 0 AND length(rp_session_ref) > 0 AND length(event_jti) > 0", name: "client_sensitive_admission_references")
  end

  def create_attachment
    create_table(:client_sensitive_admission_attachments) do |t|
      t.bigint(:sensitive_admission_id, null: false)
      t.string(:auth_ceremony_session_digest, null: false, limit: 64)
      t.uuid(:confirmation_ref, null: false)
      t.timestamptz(:attached_at, null: false)
    end
    add_check_constraint(:client_sensitive_admission_attachments, "auth_ceremony_session_digest ~ '^[0-9a-f]{64}$'", name: "client_sensitive_attach_digest")
    add_index(:client_sensitive_admission_attachments, :sensitive_admission_id, unique: true, name: "idx_client_sensitive_attach_admission")
    add_index(:client_sensitive_admission_attachments, :auth_ceremony_session_digest, unique: true, name: "idx_client_sensitive_attach_session")
    add_index(:client_sensitive_admission_attachments, :confirmation_ref, unique: true, name: "idx_client_sensitive_attach_confirmation")
    add_foreign_key(:client_sensitive_admission_attachments, :client_sensitive_admissions, column: :sensitive_admission_id, validate: false)
  end

  def create_confirmation
    create_table(:client_sensitive_admission_confirmations) do |t|
      t.bigint(:sensitive_admission_id, null: false)
      t.timestamptz(:confirmed_at, null: false)
    end
    add_index(:client_sensitive_admission_confirmations, :sensitive_admission_id, unique: true, name: "idx_client_sensitive_confirm_admission")
    add_foreign_key(:client_sensitive_admission_confirmations, :client_sensitive_admissions, column: :sensitive_admission_id, validate: false)
  end

  def create_redemption
    create_table(:client_sensitive_admission_redemptions) do |t|
      t.bigint(:sensitive_admission_id, null: false)
      t.string(:auth_ceremony_session_digest, null: false, limit: 64)
      t.string(:ceremony_ref, null: false, limit: 21)
      t.timestamptz(:redeemed_at, null: false)
      t.timestamptz(:continuation_expires_at, null: false)
    end
    add_check_constraint(:client_sensitive_admission_redemptions, "auth_ceremony_session_digest ~ '^[0-9a-f]{64}$' AND ceremony_ref ~ '^[A-Za-z0-9_-]{21}$' AND continuation_expires_at > redeemed_at", name: "client_sensitive_redeem_values")
    add_index(:client_sensitive_admission_redemptions, :sensitive_admission_id, unique: true, name: "idx_client_sensitive_redeem_admission")
    add_index(:client_sensitive_admission_redemptions, :ceremony_ref, unique: true, name: "idx_client_sensitive_redeem_ceremony")
    add_foreign_key(:client_sensitive_admission_redemptions, :client_sensitive_admissions, column: :sensitive_admission_id, validate: false)
  end
end
