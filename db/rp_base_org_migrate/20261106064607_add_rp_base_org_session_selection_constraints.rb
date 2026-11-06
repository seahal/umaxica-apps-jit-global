# frozen_string_literal: true

class AddRpBaseOrgSessionSelectionConstraints < ActiveRecord::Migration[8.2]
  TABLE = :rp_base_org_session_selections
  REQUIRED_COLUMNS = %i(
    rp_session_id account_public_id organization_public_id organization_unit_public_id selected_at created_at updated_at
  ).freeze

  def change
    REQUIRED_COLUMNS.each do |column|
      add_check_constraint(TABLE, "#{column} IS NOT NULL", name: null_constraint_name(column), validate: false)
    end
    add_check_constraint(
      TABLE,
      "char_length(account_public_id) = 21 AND char_length(organization_public_id) = 21 AND " \
      "char_length(organization_unit_public_id) = 21",
      name: "chk_rp_base_org_selection_public_ids",
      validate: false,
    )
  end

  private

  def null_constraint_name(column)
    "chk_rp_base_org_selection_#{column}_not_null"
  end
end
