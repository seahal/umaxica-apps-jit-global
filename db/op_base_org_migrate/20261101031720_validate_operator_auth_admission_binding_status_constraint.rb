# frozen_string_literal: true

class ValidateOperatorAuthAdmissionBindingStatusConstraint < ActiveRecord::Migration[8.2]
  def change
    validate_check_constraint(
      :operator_auth_admission_bindings,
      name: "operator_admission_binding_status_facts",
    )
  end
end
