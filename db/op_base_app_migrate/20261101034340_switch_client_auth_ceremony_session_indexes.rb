# frozen_string_literal: true

class SwitchClientAuthCeremonySessionIndexes < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!

  TABLE = :client_auth_ceremony_sessions

  def up
    add_index(
      TABLE, :authorization_transaction_ref,
      unique: true, name: "idx_client_auth_ceremony_sessions_state_parent",
      where: "authorization_transaction_ref IS NOT NULL AND status_id NOT IN (92, 93)",
      algorithm: :concurrently,
    )
    remove_index(TABLE, name: "idx_auth_ceremony_sessions_on_live_tx_ref", algorithm: :concurrently)
  end

  def down
    add_index(
      TABLE, :authorization_transaction_ref,
      unique: true, name: "idx_auth_ceremony_sessions_on_live_tx_ref",
      where: "authorization_transaction_ref IS NOT NULL AND cancelled_at IS NULL",
      algorithm: :concurrently,
    )
    remove_index(TABLE, name: "idx_client_auth_ceremony_sessions_state_parent", algorithm: :concurrently)
  end
end
