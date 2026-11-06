# frozen_string_literal: true

class ValidateClientAuthAdmissionBindingStatusForeignKey < ActiveRecord::Migration[8.2]
  def change
    validate_foreign_key(
      :client_auth_admission_bindings,
      name: "fk_client_admission_bindings_status",
    )
  end
end
