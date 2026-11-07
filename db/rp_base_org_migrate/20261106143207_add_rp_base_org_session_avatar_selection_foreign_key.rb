# frozen_string_literal: true

class AddRpBaseOrgSessionAvatarSelectionForeignKey < ActiveRecord::Migration[8.2]
  def change
    add_foreign_key(
      :rp_base_org_session_avatar_selections,
      :rp_base_org_session_selections,
      column: :rp_session_id,
      primary_key: :rp_session_id,
      name: "fk_rp_base_org_avatar_selection_parent",
      on_delete: :cascade,
      validate: false,
    )
  end
end
