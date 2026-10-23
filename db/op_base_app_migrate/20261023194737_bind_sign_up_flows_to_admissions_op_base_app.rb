# frozen_string_literal: true

class BindSignUpFlowsToAdmissionsOpBaseApp < ActiveRecord::Migration[8.2]
  def change
    # D-159/D-168: rebuilt databases, with no guessed ownership or backfill.
    add_reference(:client_sign_up_flows, :auth_admission_binding, index: false)
    # strong_migrations: the FK is added unvalidated here and validated by the next migration.
    add_foreign_key(
      :client_sign_up_flows, :client_auth_admission_bindings,
      column: :auth_admission_binding_id, on_delete: :restrict, validate: false,
    )
    safety_assured { change_column_null(:client_sign_up_flows, :auth_admission_binding_id, false) }
  end
end
