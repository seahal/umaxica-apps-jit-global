# frozen_string_literal: true

class CompleteRpBaseOrgSessionAvatarSelectionShape < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!

  def change
    add_reference(
      :rp_base_org_session_avatar_selections,
      :rp_session,
      null: true,
      index: false,
    )
    add_column(:rp_base_org_session_avatar_selections, :avatar_public_id, :string, limit: 21)
    add_column(:rp_base_org_session_avatar_selections, :selected_at, :datetime)
    add_timestamps(:rp_base_org_session_avatar_selections, null: true)

    add_index(
      :rp_base_org_session_avatar_selections,
      :rp_session_id,
      unique: true,
      name: "idx_rp_base_org_avatar_selection_session",
      algorithm: :concurrently,
    )
  end
end
