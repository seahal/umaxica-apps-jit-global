# frozen_string_literal: true

class ValidateRemoveLocalSignInParentOpBaseApp < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!

  def change
    validate_check_constraint(:client_auth_admission_bindings, name: "client_admission_bindings_one_parent")
    validate_check_constraint(:client_auth_admission_bindings, name: "client_admission_bindings_parent_purpose")
    validate_check_constraint(:client_auth_ceremony_sessions, name: "client_auth_ceremony_transaction_exclusive")
    validate_check_constraint(:client_auth_ceremony_sessions, name: "client_auth_admission_purpose_valid")
  end
end
