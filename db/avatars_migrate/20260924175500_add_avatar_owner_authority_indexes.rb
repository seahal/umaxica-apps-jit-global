# frozen_string_literal: true

class AddAvatarOwnerAuthorityIndexes < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!

  def up
    add_index(
      :avatar_ownership_periods,
      %i[owner_surface owner_collective_public_id],
      where: "valid_to = 'infinity'::timestamp with time zone",
      name: "idx_avatar_ownership_periods_current_owner",
      algorithm: :concurrently,
    )
    add_index(
      :avatar_group_ownership_periods,
      :avatar_group_id,
      unique: true,
      where: "valid_to = 'infinity'::timestamp with time zone",
      name: "idx_avatar_group_ownership_periods_one_current",
      algorithm: :concurrently,
    )
    add_index(
      :avatar_group_ownership_periods,
      %i[owner_surface owner_collective_public_id],
      where: "valid_to = 'infinity'::timestamp with time zone",
      name: "idx_avatar_group_ownership_periods_current_owner",
      algorithm: :concurrently,
    )
    add_index(
      :avatar_group_ownership_periods,
      :avatar_group_id,
      name: "idx_avatar_group_ownership_periods_avatar_group",
      algorithm: :concurrently,
    )
  end

  def down
    remove_index :avatar_group_ownership_periods,
                 name: "idx_avatar_group_ownership_periods_avatar_group",
                 algorithm: :concurrently
    remove_index :avatar_group_ownership_periods,
                 name: "idx_avatar_group_ownership_periods_current_owner",
                 algorithm: :concurrently
    remove_index :avatar_group_ownership_periods,
                 name: "idx_avatar_group_ownership_periods_one_current",
                 algorithm: :concurrently
    remove_index :avatar_ownership_periods,
                 name: "idx_avatar_ownership_periods_current_owner",
                 algorithm: :concurrently
  end
end
