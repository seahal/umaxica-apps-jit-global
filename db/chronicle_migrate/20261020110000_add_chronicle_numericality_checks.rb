# frozen_string_literal: true

class AddChronicleNumericalityChecks < ActiveRecord::Migration[8.2]
  # Mirrors ChronicleRetentionPolicy's greater_than_or_equal_to: 0 validation.
  def change
    add_check_constraint(
      :chronicle_retention_policies, "duration_days >= 0",
      name: "chk_chronicle_retention_policies_duration_days", validate: false,
    )
  end
end
