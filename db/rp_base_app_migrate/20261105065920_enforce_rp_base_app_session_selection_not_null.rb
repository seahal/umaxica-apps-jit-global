# frozen_string_literal: true

class EnforceRpBaseAppSessionSelectionNotNull < ActiveRecord::Migration[8.2]
  TABLE = :rp_base_app_session_selections
  REQUIRED_COLUMNS = %i(
    rp_session_id account_public_id organization_public_id organization_unit_public_id avatar_public_id
    selected_at created_at updated_at
  ).freeze

  def up
    REQUIRED_COLUMNS.each do |column|
      change_column_null(TABLE, column, false)
      remove_check_constraint(TABLE, name: null_constraint_name(column))
    end
  end

  def down
    REQUIRED_COLUMNS.each do |column|
      add_check_constraint(TABLE, "#{column} IS NOT NULL", name: null_constraint_name(column))
      change_column_null(TABLE, column, true)
    end
  end

  private

  def null_constraint_name(column)
    "chk_rp_base_app_selection_#{column}_not_null"
  end
end
