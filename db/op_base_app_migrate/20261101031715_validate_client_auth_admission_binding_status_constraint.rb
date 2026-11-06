# frozen_string_literal: true

class ValidateClientAuthAdmissionBindingStatusConstraint < ActiveRecord::Migration[8.2]
  def change
    validate_check_constraint(
      :client_auth_admission_bindings,
      name: "client_admission_binding_status_facts",
    )
  end
end
