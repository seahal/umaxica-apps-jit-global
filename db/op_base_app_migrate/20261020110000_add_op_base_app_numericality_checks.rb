# frozen_string_literal: true

class AddOpBaseAppNumericalityChecks < ActiveRecord::Migration[8.2]
  # [table, column, constraint]; each mirrors the model's greater_than_or_equal_to: 0 validation.
  CHECKS = [
    [:identity_passkey_ceremony_candidates, :sign_count, "chk_identity_passkey_candidates_sign_count"],
    [:client_oidc_authorization_transactions, :oidc_max_age, "chk_client_oidc_txns_max_age"],
    [:client_step_up_sessions, :attempt_count, "chk_client_step_up_sessions_attempt_count"],
  ].freeze

  def change
    CHECKS.each do |table, column, name|
      add_check_constraint(table, "#{column} >= 0", name:, validate: false)
    end
  end
end
