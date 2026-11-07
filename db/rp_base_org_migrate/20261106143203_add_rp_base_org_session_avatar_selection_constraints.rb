# frozen_string_literal: true

class AddRpBaseOrgSessionAvatarSelectionConstraints < ActiveRecord::Migration[8.2]
  TABLE = :rp_base_org_session_avatar_selections
  REQUIRED_COLUMNS = %i(rp_session_id avatar_public_id selected_at created_at updated_at).freeze

  def change
    REQUIRED_COLUMNS.each do |column|
      add_check_constraint(TABLE, "#{column} IS NOT NULL", name: null_constraint_name(column), validate: false)
    end
    add_check_constraint(
      TABLE,
      "char_length(avatar_public_id) = 21",
      name: "chk_rp_base_org_avatar_selection_public_id",
      validate: false,
    )
  end

  private

  def null_constraint_name(column)
    "chk_rp_base_org_avatar_selection_#{column}_not_null"
  end
end
