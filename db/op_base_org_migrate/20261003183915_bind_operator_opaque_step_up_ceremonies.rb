# frozen_string_literal: true

class BindOperatorOpaqueStepUpCeremonies < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!

  public

  def change
    add_transaction_state
    bind_auth_continuity
    bind_passkey_challenge
  end

  private

  def add_transaction_state
    table = :operator_step_up_ceremony_transactions
    add_column(table, :purpose, :string, null: false, default: "step_up")
    add_column(table, :result_digest, :string, limit: 64)
    add_column(table, :result_generation, :integer, null: false, default: 0)
    add_column(table, :result_expires_at, :datetime)
    add_column(table, :canceled_at, :datetime)
    add_column(table, :revoked_at, :datetime)
    add_index(table, :result_digest, unique: true, algorithm: :concurrently)
    add_check_constraint(
      table, "purpose IN ('step_up','reauthentication','bootstrap','credential_registration','credential_change')",
      name: "operator_step_up_purpose_valid", validate: false,
    )
    add_check_constraint(
      table, "status IN ('pending','verified','consumed','canceled','expired','revoked')",
      name: "operator_step_up_status_valid", validate: false,
    )
    add_check_constraint(
      table, "result_generation >= 0 AND ((result_digest IS NULL AND result_expires_at IS NULL " \
             "AND result_generation = 0) OR (result_digest IS NOT NULL AND result_digest ~ '^[0-9a-f]{64}$' " \
             "AND result_expires_at IS NOT NULL AND result_generation > 0 AND verified_at IS NOT NULL))",
      name: "operator_step_up_result_valid", validate: false,
    )
    add_check_constraint(
      table, "(canceled_at IS NULL OR status = 'canceled') AND (revoked_at IS NULL OR status = 'revoked') " \
             "AND (status <> 'revoked' OR revoked_at IS NOT NULL) " \
             "AND (status <> 'verified' OR (verified_at IS NOT NULL AND method IS NOT NULL AND aal IS NOT NULL))",
      name: "operator_step_up_terminal_valid", validate: false,
    )
    %w(purpose status result terminal).each do |dimension|
      validate_check_constraint(table, name: "operator_step_up_#{dimension}_valid")
    end
  end

  def bind_auth_continuity
    table = :operator_auth_ceremony_sessions
    add_column(table, :admission_purpose, :string)
    add_column(table, :step_up_ceremony_transaction_ref, :string)
    add_foreign_key(
      table, :operator_step_up_ceremony_transactions,
      column: :step_up_ceremony_transaction_ref, primary_key: :transaction_id, on_delete: :restrict, validate: false,
    )
    add_check_constraint(
      table, "num_nonnulls(authorization_transaction_ref,local_sign_in_flow_ref,local_sign_up_flow_ref," \
             "step_up_ceremony_transaction_ref) <= 1",
      name: "operator_auth_ceremony_transaction_exclusive", validate: false,
    )
    add_check_constraint(
      table, "admission_purpose IS NULL OR admission_purpose IN ('local_sign_in','local_sign_up'," \
             "'authentication_handoff','invitation_handoff','step_up_handoff','reauthentication_handoff')",
      name: "operator_auth_admission_purpose_valid", validate: false,
    )
    validate_foreign_key(table, :operator_step_up_ceremony_transactions)
    validate_check_constraint(table, name: "operator_auth_ceremony_transaction_exclusive")
    validate_check_constraint(table, name: "operator_auth_admission_purpose_valid")
  end

  def bind_passkey_challenge
    table = :operator_step_up_sessions
    add_column(table, :step_up_ceremony_transaction_ref, :string)
    add_column(table, :passkey_challenge, :text)
    add_column(table, :passkey_challenge_ref, :string)
    add_column(table, :passkey_rp_id, :string)
    add_column(table, :passkey_origin, :string)
    add_column(table, :passkey_challenge_expires_at, :datetime)
    add_column(table, :passkey_challenge_consumed_at, :datetime)
    add_index(table, :step_up_ceremony_transaction_ref, unique: true, algorithm: :concurrently)
    add_index(table, :passkey_challenge_ref, unique: true, algorithm: :concurrently)
    add_foreign_key(
      table, :operator_step_up_ceremony_transactions,
      column: :step_up_ceremony_transaction_ref, primary_key: :transaction_id, on_delete: :restrict, validate: false,
    )
    add_check_constraint(
      table, "passkey_challenge IS NULL OR (step_up_ceremony_transaction_ref IS NOT NULL " \
             "AND passkey_challenge_ref IS NOT NULL AND passkey_rp_id IS NOT NULL AND passkey_origin IS NOT NULL " \
             "AND passkey_challenge_expires_at IS NOT NULL AND passkey_challenge_expires_at <= discard_at)",
      name: "operator_step_up_challenge_bound", validate: false,
    )
    validate_foreign_key(table, :operator_step_up_ceremony_transactions)
    validate_check_constraint(table, name: "operator_step_up_challenge_bound")
  end
end
