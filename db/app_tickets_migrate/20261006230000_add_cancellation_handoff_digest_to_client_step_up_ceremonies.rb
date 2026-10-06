# frozen_string_literal: true

class AddCancellationHandoffDigestToClientStepUpCeremonies < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!

  public

  def change
    table = :client_step_up_ceremony_transactions
    add_column table, :cancellation_handoff_digest, :string, limit: 64
    add_column table, :cancellation_handoff_ref, :uuid
    add_column table, :cancellation_handoff_ciphertext, :text
    add_index table, :cancellation_handoff_digest, unique: true, algorithm: :concurrently
    add_index table, :cancellation_handoff_ref, unique: true, algorithm: :concurrently
    add_check_constraint(
      table, "cancellation_handoff_digest IS NULL OR cancellation_handoff_digest ~ '^[0-9a-f]{64}$'",
      name: "client_step_up_cancellation_handoff_valid", validate: false,
    )
    add_check_constraint(
      table,
      "(cancellation_handoff_ref IS NULL AND cancellation_handoff_ciphertext IS NULL) OR " \
        "(cancellation_handoff_ref IS NOT NULL AND cancellation_handoff_ciphertext IS NOT NULL)",
      name: "client_step_up_cancellation_handoff_pair", validate: false,
    )
    validate_check_constraint table, name: "client_step_up_cancellation_handoff_valid"
    validate_check_constraint table, name: "client_step_up_cancellation_handoff_pair"
  end
end
