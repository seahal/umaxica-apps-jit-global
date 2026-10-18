# typed: false
# frozen_string_literal: true

class CreateRpCoreOrgLocalSchema < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!

  def up
    create_tables!
    create_indexes!
    create_foreign_keys!
    create_checks!
  end

  def down
    raise ActiveRecord::IrreversibleMigration, "R5 RP local state is forward-only"
  end

  private

  def create_tables!
    create_table(:rp_principals, id: :bigserial, if_not_exists: true) do |t|
      t.string(:public_id, null: false, limit: 21)
      t.datetime(:disabled_at)
      t.timestamps
    end

    create_table(:rp_identity_bindings, id: :bigserial, if_not_exists: true) do |t|
      t.references(:principal, null: false, index: false)
      t.string(:issuer, null: false, limit: 255)
      t.string(:realm, null: false, limit: 3)
      t.string(:client_id, null: false, limit: 64)
      t.string(:subject, null: false, limit: 255)
      t.timestamps
    end

    create_table(:rp_op_session_bindings, id: :bigserial, if_not_exists: true) do |t|
      t.references(:identity_binding, index: false)
      t.string(:issuer, null: false, limit: 255)
      t.string(:realm, null: false, limit: 3)
      t.string(:client_id, null: false, limit: 64)
      t.string(:sid, null: false, limit: 255)
      t.datetime(:revoked_at)
      t.timestamps
    end

    create_table(:rp_sessions, id: :bigserial, if_not_exists: true) do |t|
      t.string(:public_id, null: false, limit: 21)
      t.references(:op_session_binding, null: false, index: false)
      t.datetime(:absolute_expires_at, null: false)
      t.datetime(:revoked_at)
      t.bigint(:installed_generation, null: false, default: 0)
      t.string(:current_access_jti_digest, limit: 64)
      t.datetime(:current_access_expires_at)
      t.bigint(:contract_epoch, null: false, default: 1)
      t.timestamps
    end

    create_table(:rp_callback_states, id: :bigserial, if_not_exists: true) do |t|
      t.binary(:state_digest, null: false, limit: 32)
      t.binary(:browser_binding_digest, null: false, limit: 32)
      t.binary(:nonce_digest, null: false, limit: 32)
      t.string(:pkce_challenge, null: false, limit: 128)
      t.text(:pkce_verifier_ciphertext, null: false)
      t.string(:issuer, null: false, limit: 255)
      t.string(:realm, null: false, limit: 3)
      t.string(:client_id, null: false, limit: 64)
      t.datetime(:expires_at, null: false)
      t.datetime(:consumed_at)
      t.timestamps
    end

    create_table(:rp_refresh_attempts, id: :bigserial, if_not_exists: true) do |t|
      t.string(:public_id, null: false, limit: 21)
      t.references(:session, null: false, index: false)
      t.binary(:input_hmac, null: false, limit: 32)
      t.bigint(:expected_installed_generation, null: false)
      t.datetime(:dispatched_at)
      t.datetime(:uncertain_at)
      t.datetime(:installed_at)
      t.datetime(:expires_at, null: false)
      t.timestamps
    end

    create_table(:rp_event_receipts, id: :bigserial, if_not_exists: true) do |t|
      t.references(:op_session_binding, null: false, index: false)
      t.string(:issuer, null: false, limit: 255)
      t.string(:realm, null: false, limit: 3)
      t.string(:client_id, null: false, limit: 64)
      t.string(:event_type, null: false, limit: 64)
      t.binary(:jti_digest, null: false, limit: 32)
      t.datetime(:expires_at, null: false)
      t.datetime(:committed_at, null: false)
      t.timestamps
    end
  end

  def create_indexes!
    add_index(:rp_principals, :public_id, unique: true, name: "idx_rp_core_org_principals_public_id", if_not_exists: true)
    add_index(
      :rp_identity_bindings, %i(issuer realm client_id subject), unique: true,
      name: "idx_rp_core_org_identity_bindings_identity", if_not_exists: true,
    )
    add_index(
      :rp_op_session_bindings, %i(issuer realm client_id sid), unique: true,
      name: "idx_rp_core_org_op_session_bindings_identity", if_not_exists: true,
    )
    add_index(:rp_sessions, :public_id, unique: true, name: "idx_rp_core_org_sessions_public_id", if_not_exists: true)
    add_index(
      :rp_sessions, :op_session_binding_id, unique: true, where: "revoked_at IS NULL",
      name: "idx_rp_core_org_sessions_live_binding", if_not_exists: true,
    )
    add_index(:rp_callback_states, :state_digest, unique: true, name: "idx_rp_core_org_callback_states_state", if_not_exists: true)
    add_index(:rp_callback_states, :expires_at, name: "idx_rp_core_org_callback_states_expiry", if_not_exists: true)
    add_index(:rp_refresh_attempts, :public_id, unique: true, name: "idx_rp_core_org_refresh_attempts_public_id", if_not_exists: true)
    add_index(:rp_refresh_attempts, :expires_at, name: "idx_rp_core_org_refresh_attempts_expiry", if_not_exists: true)
    add_index(
      :rp_event_receipts, %i(issuer realm client_id event_type jti_digest), unique: true,
      name: "idx_rp_core_org_event_receipts_identity", if_not_exists: true,
    )
  end

  def create_foreign_keys!
    add_foreign_key(
      :rp_identity_bindings, :rp_principals, column: :principal_id,
      name: "fk_rp_core_org_identity_bindings_principal", if_not_exists: true, validate: false,
    )
    add_foreign_key(
      :rp_op_session_bindings, :rp_identity_bindings, column: :identity_binding_id,
      name: "fk_rp_core_org_op_session_bindings_identity", if_not_exists: true, validate: false,
    )
    add_foreign_key(
      :rp_sessions, :rp_op_session_bindings, column: :op_session_binding_id,
      name: "fk_rp_core_org_sessions_op_binding", if_not_exists: true, validate: false,
    )
    add_foreign_key(
      :rp_refresh_attempts, :rp_sessions, column: :session_id,
      name: "fk_rp_core_org_refresh_attempts_session", if_not_exists: true, validate: false,
    )
    add_foreign_key(
      :rp_event_receipts, :rp_op_session_bindings, column: :op_session_binding_id,
      name: "fk_rp_core_org_event_receipts_op_binding", if_not_exists: true, validate: false,
    )
  end

  def create_checks!
    add_check_constraint(
      :rp_identity_bindings, "realm = 'org' AND client_id = 'core-org-jp'",
      name: "chk_rp_core_org_identity_bindings_cell", if_not_exists: true, validate: false,
    )
    add_check_constraint(
      :rp_op_session_bindings, "realm = 'org' AND client_id = 'core-org-jp'",
      name: "chk_rp_core_org_op_session_bindings_cell", if_not_exists: true, validate: false,
    )
    add_check_constraint(
      :rp_sessions, "installed_generation >= 0 AND contract_epoch >= 1",
      name: "chk_rp_core_org_sessions_shape", if_not_exists: true, validate: false,
    )
    add_check_constraint(
      :rp_callback_states, "realm = 'org' AND client_id = 'core-org-jp'",
      name: "chk_rp_core_org_callback_states_cell", if_not_exists: true, validate: false,
    )
    add_check_constraint(
      :rp_refresh_attempts, "expected_installed_generation >= 0",
      name: "chk_rp_core_org_refresh_attempts_shape", if_not_exists: true, validate: false,
    )
    add_check_constraint(
      :rp_event_receipts, "realm = 'org' AND client_id = 'core-org-jp'",
      name: "chk_rp_core_org_event_receipts_cell", if_not_exists: true, validate: false,
    )
  end
end
