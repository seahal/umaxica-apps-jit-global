# frozen_string_literal: true

class ValidateOpBaseComNumericalityChecks < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!

  def change
    validate_check_constraint(:visitor_passkey_ceremony_candidates, name: "chk_visitor_passkey_candidates_sign_count")
    validate_check_constraint(:visitor_oidc_authorization_transactions, name: "chk_visitor_oidc_txns_max_age")
    validate_check_constraint(:visitor_step_up_sessions, name: "chk_visitor_step_up_sessions_attempt_count")
  end
end
