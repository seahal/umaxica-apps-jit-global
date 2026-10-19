# frozen_string_literal: true

# D06 Switch: an admission issued by a Switch names the flow it opens, because the parent keeps its
# neutral authentication intent. Ordinary admissions leave it NULL and follow the parent intent.
class AddEntryIntentToClientAuthAdmissionBindings < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!

  public

  def change
    add_column(:client_auth_admission_bindings, :entry_intent, :string)
    add_check_constraint(
      :client_auth_admission_bindings, "entry_intent IS NULL OR entry_intent IN ('sign_in', 'sign_up')",
      name: "client_admission_binding_entry_intent", validate: false,
    )
    validate_check_constraint(:client_auth_admission_bindings, name: "client_admission_binding_entry_intent")
  end
end
