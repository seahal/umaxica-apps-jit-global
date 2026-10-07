# typed: false
# frozen_string_literal: true

class PermitOperatorAuthAdmissionTabs < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!

  def up
    add_index(
      :operator_auth_admission_bindings, :auth_ceremony_session_id,
      name: "idx_operator_admission_bindings_auth_session", where: "auth_ceremony_session_id IS NOT NULL",
      algorithm: :concurrently,
    )
    remove_index(
      :operator_auth_admission_bindings, name: "idx_on_auth_ceremony_session_id_207296f643",
                                         algorithm: :concurrently,
    )
  end

  def down
    # Duplicate sid references must refuse rollback, never delete another tab's binding.
    add_index(
      :operator_auth_admission_bindings, :auth_ceremony_session_id,
      name: "idx_on_auth_ceremony_session_id_207296f643", unique: true,
      where: "auth_ceremony_session_id IS NOT NULL", algorithm: :concurrently,
    )
    remove_index(
      :operator_auth_admission_bindings, name: "idx_operator_admission_bindings_auth_session",
                                         algorithm: :concurrently,
    )
  end
end
