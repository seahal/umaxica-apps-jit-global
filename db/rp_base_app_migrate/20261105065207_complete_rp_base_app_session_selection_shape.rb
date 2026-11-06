# frozen_string_literal: true

class CompleteRpBaseAppSessionSelectionShape < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!

  def change
    add_reference(
      :rp_base_app_session_selections,
      :rp_session,
      null: true,
      index: false,
    )
    add_column(:rp_base_app_session_selections, :account_public_id, :string, limit: 21)
    add_column(:rp_base_app_session_selections, :organization_public_id, :string, limit: 21)
    add_column(:rp_base_app_session_selections, :organization_unit_public_id, :string, limit: 21)
    add_column(:rp_base_app_session_selections, :avatar_public_id, :string, limit: 21)
    add_column(:rp_base_app_session_selections, :selected_at, :datetime)
    add_timestamps(:rp_base_app_session_selections, null: true)

    add_index(
      :rp_base_app_session_selections,
      :rp_session_id,
      unique: true,
      name: "idx_rp_base_app_selection_session",
      algorithm: :concurrently,
    )
  end
end
