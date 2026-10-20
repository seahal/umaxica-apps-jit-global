# frozen_string_literal: true

class ValidateOpBaseAppNumericalityChecks < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!

  def change
    validate_check_constraint(:identity_passkey_ceremony_candidates, name: "chk_identity_passkey_candidates_sign_count")
    validate_check_constraint(:client_oidc_authorization_transactions, name: "chk_client_oidc_txns_max_age")
    validate_check_constraint(:client_step_up_sessions, name: "chk_client_step_up_sessions_attempt_count")
  end
end
