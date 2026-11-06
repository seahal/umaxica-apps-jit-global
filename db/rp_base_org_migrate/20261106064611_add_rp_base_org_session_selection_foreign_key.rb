# frozen_string_literal: true

class AddRpBaseOrgSessionSelectionForeignKey < ActiveRecord::Migration[8.2]
  def change
    add_foreign_key(
      :rp_base_org_session_selections,
      :rp_sessions,
      column: :rp_session_id,
      name: "fk_rp_base_org_selection_session",
      on_delete: :cascade,
      validate: false,
    )
  end
end
