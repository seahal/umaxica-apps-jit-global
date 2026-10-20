# frozen_string_literal: true

class AddComZenithNumericalityChecks < ActiveRecord::Migration[8.2]
  # [table, column, constraint]; each mirrors the model's greater_than_or_equal_to: 0 validation.
  CHECKS = [
    [:visitor_passkeys, :sign_count, "chk_visitor_passkeys_sign_count"],
    [:visitor_secret_credential_kinds, :id, "chk_visitor_secret_credential_kinds_id"],
  ].freeze

  def change
    CHECKS.each do |table, column, name|
      add_check_constraint(table, "#{column} >= 0", name:, validate: false)
    end
  end
end
