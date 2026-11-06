# frozen_string_literal: true

class ValidateRpBaseOrgSessionSelectionConstraints < ActiveRecord::Migration[8.2]
  REQUIRED_COLUMNS = %i(
    rp_session_id account_public_id organization_public_id organization_unit_public_id selected_at created_at updated_at
  ).freeze

  def change
    REQUIRED_COLUMNS.each do |column|
      validate_check_constraint(
        :rp_base_org_session_selections,
        name: "chk_rp_base_org_selection_#{column}_not_null",
      )
    end
    validate_check_constraint(:rp_base_org_session_selections, name: "chk_rp_base_org_selection_public_ids")
    validate_foreign_key(:rp_base_org_session_selections, :rp_sessions, name: "fk_rp_base_org_selection_session")
  end
end
