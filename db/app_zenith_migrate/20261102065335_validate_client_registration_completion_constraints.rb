# frozen_string_literal: true

class ValidateClientRegistrationCompletionConstraints < ActiveRecord::Migration[8.2]
  public

  def change
    validate_foreign_key(:client_registration_completions, :clients)
    validate_foreign_key(:client_registration_completions, :client_registration_completion_methods)
    validate_check_constraint(:client_registration_completion_methods, name: "chk_client_registration_completion_methods")
    validate_check_constraint(:client_registration_completions, name: "chk_client_registration_completion_public_id")
    validate_check_constraint(:client_registration_completions, name: "chk_client_registration_completion_flow_ref")
    validate_check_constraint(:client_registration_completions, name: "chk_client_registration_completion_time")
  end
end
