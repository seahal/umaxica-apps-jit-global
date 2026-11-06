# frozen_string_literal: true

class ValidateOperatorAuthAdmissionBindingStatusForeignKey < ActiveRecord::Migration[8.2]
  def change
    validate_foreign_key(
      :operator_auth_admission_bindings,
      name: "fk_operator_admission_bindings_status",
    )
  end
end
