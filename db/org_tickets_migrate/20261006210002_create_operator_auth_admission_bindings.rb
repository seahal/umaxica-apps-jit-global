# typed: false
# frozen_string_literal: true

class CreateOperatorAuthAdmissionBindings < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!

  def change
    create_table :operator_auth_admission_bindings, if_not_exists: true do |t|
      t.uuid :entry_ref, null: false
      t.string :purpose, null: false
      t.bigint :sign_in_flow_id
      t.bigint :authorization_transaction_id
      t.bigint :step_up_ceremony_transaction_id
      t.bigint :base_token_id
      t.string :base_browser_digest, null: false, limit: 64
      t.bigint :auth_ceremony_session_id
      t.uuid :confirmation_ref
      t.timestamptz :base_confirmed_at
      t.timestamptz :redeemed_at
      t.bigint :admitted_auth_ceremony_session_id
      t.timestamptz :retired_at
      t.timestamptz :expires_at, null: false
      t.timestamps(type: :timestamptz)
    end

    add_foreign_key :operator_auth_admission_bindings, :operator_sign_in_flows,
                    column: :sign_in_flow_id, on_delete: :restrict, validate: false, if_not_exists: true
    add_foreign_key :operator_auth_admission_bindings, :operator_oidc_authorization_transactions,
                    column: :authorization_transaction_id, on_delete: :restrict, validate: false, if_not_exists: true
    add_foreign_key :operator_auth_admission_bindings, :operator_step_up_ceremony_transactions,
                    column: :step_up_ceremony_transaction_id, on_delete: :restrict, validate: false, if_not_exists: true
    add_foreign_key :operator_auth_admission_bindings, :operator_tokens,
                    column: :base_token_id, on_delete: :restrict, validate: false, if_not_exists: true
    add_foreign_key :operator_auth_admission_bindings, :operator_auth_ceremony_sessions,
                    column: :auth_ceremony_session_id, on_delete: :restrict, validate: false, if_not_exists: true
    add_foreign_key :operator_auth_admission_bindings, :operator_auth_ceremony_sessions,
                    column: :admitted_auth_ceremony_session_id, on_delete: :restrict,
                    name: "fk_operator_auth_admission_bindings_admitted_session", validate: false, if_not_exists: true

    add_index :operator_auth_admission_bindings, :entry_ref, unique: true, algorithm: :concurrently,
                                                               if_not_exists: true
    add_index :operator_auth_admission_bindings, :confirmation_ref, unique: true,
                                                                     where: "confirmation_ref IS NOT NULL",
                                                                     algorithm: :concurrently, if_not_exists: true
    add_index :operator_auth_admission_bindings, :auth_ceremony_session_id, unique: true,
                                                                            where: "auth_ceremony_session_id IS NOT NULL",
                                                                            algorithm: :concurrently, if_not_exists: true
    add_index :operator_auth_admission_bindings, :expires_at, algorithm: :concurrently, if_not_exists: true
    add_index :operator_auth_admission_bindings, :sign_in_flow_id, unique: true,
                                                                    where: "sign_in_flow_id IS NOT NULL AND retired_at IS NULL AND redeemed_at IS NULL",
                                                                    name: "idx_operator_admission_bindings_live_sign_in",
                                                                    algorithm: :concurrently, if_not_exists: true
    add_index :operator_auth_admission_bindings, :authorization_transaction_id, unique: true,
                                                                                 where: "authorization_transaction_id IS NOT NULL AND retired_at IS NULL AND redeemed_at IS NULL",
                                                                                 name: "idx_operator_admission_bindings_live_oidc",
                                                                                 algorithm: :concurrently, if_not_exists: true
    add_index :operator_auth_admission_bindings, :step_up_ceremony_transaction_id, unique: true,
                                                                                    where: "step_up_ceremony_transaction_id IS NOT NULL AND retired_at IS NULL AND redeemed_at IS NULL",
                                                                                    name: "idx_operator_admission_bindings_live_step_up",
                                                                                    algorithm: :concurrently, if_not_exists: true

    add_check_constraint :operator_auth_admission_bindings,
                         "num_nonnulls(sign_in_flow_id, authorization_transaction_id, step_up_ceremony_transaction_id) = 1",
                         name: "operator_admission_bindings_one_parent", if_not_exists: true
    add_check_constraint :operator_auth_admission_bindings,
                         "(sign_in_flow_id IS NULL OR purpose IN ('local_sign_in', 'local_sign_up')) AND " \
                         "(authorization_transaction_id IS NULL OR purpose IN ('authentication_handoff', 'invitation_handoff')) AND " \
                         "(step_up_ceremony_transaction_id IS NULL OR purpose IN ('step_up_handoff', 'reauthentication_handoff', 'bootstrap_handoff', 'credential_registration_handoff', 'credential_change_handoff'))",
                         name: "operator_admission_bindings_parent_purpose", if_not_exists: true
    add_check_constraint :operator_auth_admission_bindings,
                         "(purpose NOT IN ('step_up_handoff', 'reauthentication_handoff', 'bootstrap_handoff', 'credential_registration_handoff', 'credential_change_handoff') OR base_token_id IS NOT NULL)",
                         name: "operator_admission_bindings_step_up_token", if_not_exists: true
    add_check_constraint :operator_auth_admission_bindings,
                         "(auth_ceremony_session_id IS NULL AND confirmation_ref IS NULL) OR (auth_ceremony_session_id IS NOT NULL AND confirmation_ref IS NOT NULL)",
                         name: "operator_admission_bindings_auth_proof_pair", if_not_exists: true
    add_check_constraint :operator_auth_admission_bindings,
                         "(redeemed_at IS NULL AND admitted_auth_ceremony_session_id IS NULL) OR (redeemed_at IS NOT NULL AND admitted_auth_ceremony_session_id IS NOT NULL)",
                         name: "operator_admission_bindings_redemption_pair", if_not_exists: true
    add_check_constraint :operator_auth_admission_bindings,
                         "NOT (redeemed_at IS NOT NULL AND retired_at IS NOT NULL)",
                         name: "operator_admission_bindings_terminal_exclusive", if_not_exists: true
    add_check_constraint :operator_auth_admission_bindings,
                         "base_confirmed_at IS NULL OR (auth_ceremony_session_id IS NOT NULL AND confirmation_ref IS NOT NULL)",
                         name: "operator_admission_bindings_confirmation_requires_auth", if_not_exists: true
  end
end
