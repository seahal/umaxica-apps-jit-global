# frozen_string_literal: true

class AddActiveStatusIndexesToOperatorAuthAdmissionBindings < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!

  def up
    add_index(
      :operator_auth_admission_bindings,
      [:authorization_transaction_id, :purpose],
      unique: true,
      where: "authorization_transaction_id IS NOT NULL AND status_id IN (10, 20, 30)",
      name: "idx_operator_admission_active_oidc_purpose",
      algorithm: :concurrently,
    )
    add_index(
      :operator_auth_admission_bindings,
      [:step_up_ceremony_transaction_id, :purpose],
      unique: true,
      where: "step_up_ceremony_transaction_id IS NOT NULL AND status_id IN (10, 20, 30)",
      name: "idx_operator_admission_active_step_purpose",
      algorithm: :concurrently,
    )
  end

  def down
    remove_index(:operator_auth_admission_bindings, name: "idx_operator_admission_active_step_purpose", algorithm: :concurrently)
    remove_index(:operator_auth_admission_bindings, name: "idx_operator_admission_active_oidc_purpose", algorithm: :concurrently)
  end
end
