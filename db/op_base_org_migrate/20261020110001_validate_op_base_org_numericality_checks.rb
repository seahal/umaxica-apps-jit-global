# frozen_string_literal: true

class ValidateOpBaseOrgNumericalityChecks < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!

  def change
    validate_check_constraint(:operator_passkey_ceremony_candidates, name: "chk_operator_passkey_candidates_sign_count")
    validate_check_constraint(:operator_oidc_authorization_transactions, name: "chk_operator_oidc_txns_max_age")
    validate_check_constraint(:operator_step_up_sessions, name: "chk_operator_step_up_sessions_attempt_count")
  end
end
