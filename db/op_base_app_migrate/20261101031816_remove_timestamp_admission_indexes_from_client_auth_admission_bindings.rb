# frozen_string_literal: true

class RemoveTimestampAdmissionIndexesFromClientAuthAdmissionBindings < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!

  def up
    remove_index(:client_auth_admission_bindings, name: "idx_client_admission_bindings_live_oidc", algorithm: :concurrently)
    remove_index(:client_auth_admission_bindings, name: "idx_client_admission_bindings_live_step_up", algorithm: :concurrently)
  end

  def down
    add_index(
      :client_auth_admission_bindings,
      :authorization_transaction_id,
      unique: true,
      where: "authorization_transaction_id IS NOT NULL AND retired_at IS NULL AND redeemed_at IS NULL",
      name: "idx_client_admission_bindings_live_oidc",
      algorithm: :concurrently,
    )
    add_index(
      :client_auth_admission_bindings,
      :step_up_ceremony_transaction_id,
      unique: true,
      where: "step_up_ceremony_transaction_id IS NOT NULL AND retired_at IS NULL AND redeemed_at IS NULL",
      name: "idx_client_admission_bindings_live_step_up",
      algorithm: :concurrently,
    )
  end
end
