# frozen_string_literal: true

class ValidateRpBaseOrgSessionAvatarSelectionConstraints < ActiveRecord::Migration[8.2]
  def change
    %i(rp_session_id avatar_public_id selected_at created_at updated_at).each do |column|
      validate_check_constraint(
        :rp_base_org_session_avatar_selections,
        name: "chk_rp_base_org_avatar_selection_#{column}_not_null",
      )
    end
    validate_check_constraint(
      :rp_base_org_session_avatar_selections,
      name: "chk_rp_base_org_avatar_selection_public_id",
    )
    validate_foreign_key(
      :rp_base_org_session_avatar_selections,
      :rp_base_org_session_selections,
      name: "fk_rp_base_org_avatar_selection_parent",
    )
  end
end
