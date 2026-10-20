# frozen_string_literal: true

class AddOpBaseComNumericalityChecks < ActiveRecord::Migration[8.2]
  # [table, column, constraint]; each mirrors the model's greater_than_or_equal_to: 0 validation.
  CHECKS = [
    [:visitor_passkey_ceremony_candidates, :sign_count, "chk_visitor_passkey_candidates_sign_count"],
    [:visitor_oidc_authorization_transactions, :oidc_max_age, "chk_visitor_oidc_txns_max_age"],
    [:visitor_step_up_sessions, :attempt_count, "chk_visitor_step_up_sessions_attempt_count"],
  ].freeze

  def change
    CHECKS.each do |table, column, name|
      add_check_constraint(table, "#{column} >= 0", name:, validate: false)
    end
  end
end
