# typed: false
# frozen_string_literal: true

class PermitClientAuthAdmissionTabs < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!

  def up
    add_index(
      :client_auth_admission_bindings, :auth_ceremony_session_id,
      name: "idx_client_admission_bindings_auth_session", where: "auth_ceremony_session_id IS NOT NULL",
      algorithm: :concurrently,
    )
    remove_index(
      :client_auth_admission_bindings, name: "idx_on_auth_ceremony_session_id_16d666c06f",
                                       algorithm: :concurrently,
    )
  end

  def down
    # Duplicate sid references must refuse rollback, never delete another tab's binding.
    add_index(
      :client_auth_admission_bindings, :auth_ceremony_session_id,
      name: "idx_on_auth_ceremony_session_id_16d666c06f", unique: true,
      where: "auth_ceremony_session_id IS NOT NULL", algorithm: :concurrently,
    )
    remove_index(
      :client_auth_admission_bindings, name: "idx_client_admission_bindings_auth_session",
                                       algorithm: :concurrently,
    )
  end
end
