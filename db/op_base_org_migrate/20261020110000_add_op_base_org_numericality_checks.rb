# frozen_string_literal: true

class AddOpBaseOrgNumericalityChecks < ActiveRecord::Migration[8.2]
  # [table, column, constraint]; each mirrors the model's greater_than_or_equal_to: 0 validation.
  CHECKS = [
    [:operator_passkey_ceremony_candidates, :sign_count, "chk_operator_passkey_candidates_sign_count"],
    [:operator_oidc_authorization_transactions, :oidc_max_age, "chk_operator_oidc_txns_max_age"],
    [:operator_step_up_sessions, :attempt_count, "chk_operator_step_up_sessions_attempt_count"],
  ].freeze

  def change
    CHECKS.each do |table, column, name|
      add_check_constraint(table, "#{column} >= 0", name:, validate: false)
    end
  end
end
