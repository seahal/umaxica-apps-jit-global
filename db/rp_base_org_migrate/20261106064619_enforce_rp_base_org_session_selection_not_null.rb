# frozen_string_literal: true

class EnforceRpBaseOrgSessionSelectionNotNull < ActiveRecord::Migration[8.2]
  TABLE = :rp_base_org_session_selections
  REQUIRED_COLUMNS = %i(
    rp_session_id account_public_id organization_public_id organization_unit_public_id selected_at created_at updated_at
  ).freeze

  def change
    REQUIRED_COLUMNS.each do |column|
      change_column_null(TABLE, column, false)
      remove_check_constraint(TABLE, name: "chk_rp_base_org_selection_#{column}_not_null")
    end
  end
end
