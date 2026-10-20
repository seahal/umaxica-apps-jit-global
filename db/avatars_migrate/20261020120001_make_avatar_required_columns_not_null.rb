# frozen_string_literal: true

class MakeAvatarRequiredColumnsNotNull < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!

  COLUMNS = [
    [:handle_assignments, :handle_assignment_status_id, "chk_handle_assignments_status_id_nn"],
    [:handles, :handle_status_id, "chk_handles_status_id_nn"],
    [:avatar_ownership_periods, :owner_collective_public_id, "chk_avatar_ownership_periods_owner_ref_nn"],
    [:avatar_memberships, :avatar_membership_status_id, "chk_avatar_memberships_status_id_nn"],
  ].freeze

  # Validating the check first lets SET NOT NULL skip its full-table scan.
  def up
    COLUMNS.each do |table, column, name|
      validate_check_constraint(table, name:)
      change_column_null(table, column, false)
      remove_check_constraint(table, name:)
    end
  end

  def down
    COLUMNS.each do |table, column, name|
      add_check_constraint(table, "#{column} IS NOT NULL", name:, validate: false)
      change_column_null(table, column, true)
    end
  end
end
