# frozen_string_literal: true

class ValidateChronicleNumericalityChecks < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!

  def change
    validate_check_constraint(:chronicle_retention_policies, name: "chk_chronicle_retention_policies_duration_days")
  end
end
