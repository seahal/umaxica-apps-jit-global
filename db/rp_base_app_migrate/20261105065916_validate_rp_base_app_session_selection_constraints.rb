# frozen_string_literal: true

class ValidateRpBaseAppSessionSelectionConstraints < ActiveRecord::Migration[8.2]
  REQUIRED_COLUMNS = %i(
    rp_session_id account_public_id organization_public_id organization_unit_public_id avatar_public_id
    selected_at created_at updated_at
  ).freeze

  def up
    REQUIRED_COLUMNS.each do |column|
      validate_check_constraint(
        :rp_base_app_session_selections,
        name: "chk_rp_base_app_selection_#{column}_not_null",
      )
    end
    validate_check_constraint(:rp_base_app_session_selections, name: "chk_rp_base_app_selection_public_ids")
    validate_foreign_key(:rp_base_app_session_selections, :rp_sessions, name: "fk_rp_base_app_selection_session")
  end

  def down
    remove_foreign_key(:rp_base_app_session_selections, name: "fk_rp_base_app_selection_session")
    add_foreign_key(
      :rp_base_app_session_selections,
      :rp_sessions,
      column: :rp_session_id,
      name: "fk_rp_base_app_selection_session",
      on_delete: :cascade,
      validate: false,
    )
    REQUIRED_COLUMNS.each do |column|
      name = "chk_rp_base_app_selection_#{column}_not_null"
      remove_check_constraint(:rp_base_app_session_selections, name:)
      add_check_constraint(:rp_base_app_session_selections, "#{column} IS NOT NULL", name:, validate: false)
    end
    remove_check_constraint(:rp_base_app_session_selections, name: "chk_rp_base_app_selection_public_ids")
    add_check_constraint(
      :rp_base_app_session_selections,
      "char_length(account_public_id) = 21 AND char_length(organization_public_id) = 21 AND " \
      "char_length(organization_unit_public_id) = 21 AND char_length(avatar_public_id) = 21",
      name: "chk_rp_base_app_selection_public_ids",
      validate: false,
    )
  end
end
