# frozen_string_literal: true

class AddAvatarRequiredNotNullChecks < ActiveRecord::Migration[8.2]
  # [table, column, temporary constraint]; the model already requires each column on every save.
  COLUMNS = [
    [:handle_assignments, :handle_assignment_status_id, "chk_handle_assignments_status_id_nn"],
    [:handles, :handle_status_id, "chk_handles_status_id_nn"],
    [:avatar_ownership_periods, :owner_collective_public_id, "chk_avatar_ownership_periods_owner_ref_nn"],
    [:avatar_memberships, :avatar_membership_status_id, "chk_avatar_memberships_status_id_nn"],
  ].freeze

  def change
    COLUMNS.each do |table, column, name|
      add_check_constraint(table, "#{column} IS NOT NULL", name:, validate: false)
    end
  end
end
