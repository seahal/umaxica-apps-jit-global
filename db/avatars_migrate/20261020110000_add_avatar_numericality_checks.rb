# frozen_string_literal: true

class AddAvatarNumericalityChecks < ActiveRecord::Migration[8.2]
  # [table, column, constraint]; each mirrors the model's greater_than_or_equal_to: 0 validation.
  CHECKS = [
    [:group_avatar_memberships, :position, "chk_group_avatar_memberships_position"],
  ].freeze

  def change
    CHECKS.each do |table, column, name|
      add_check_constraint(table, "#{column} >= 0", name:, validate: false)
    end
  end
end
