# frozen_string_literal: true

class AddAppZenithNumericalityChecks < ActiveRecord::Migration[8.2]
  # [table, column, constraint]; each mirrors the model's greater_than_or_equal_to: 0 validation.
  CHECKS = [
    [:client_passkeys, :sign_count, "chk_client_passkeys_sign_count"],
  ].freeze

  def change
    CHECKS.each do |table, column, name|
      add_check_constraint(table, "#{column} >= 0", name:, validate: false)
    end
  end
end
