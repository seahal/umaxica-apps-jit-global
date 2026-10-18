# frozen_string_literal: true

class AddAvatarAndGroupOwnerAuthority < ActiveRecord::Migration[8.2]
  def up
    add_column :avatar_ownership_periods, :owner_surface, :string
    add_column :avatar_ownership_periods, :owner_collective_public_id, :string
    add_check_constraint(
      :avatar_ownership_periods,
      "owner_surface IN ('app', 'org') AND owner_collective_public_id IS NOT NULL AND owner_collective_public_id <> ''",
      name: "chk_avatar_ownership_periods_owner_reference",
      validate: false,
    )
    create_table :avatar_group_ownership_periods do |t|
      t.references :avatar_group, null: false, index: false, foreign_key: { on_delete: :restrict }
      t.string :owner_surface, null: false
      t.string :owner_collective_public_id, null: false
      t.datetime :valid_from, null: false
      t.datetime :valid_to, null: false, default: Float::INFINITY

      t.timestamps
    end

    add_check_constraint(
      :avatar_group_ownership_periods,
      "owner_surface IN ('app', 'org')",
      name: "chk_avatar_group_ownership_periods_owner_surface",
    )
    add_check_constraint(
      :avatar_group_ownership_periods,
      "owner_collective_public_id <> ''",
      name: "chk_avatar_group_ownership_periods_owner_collective",
    )
    add_check_constraint(
      :avatar_group_ownership_periods,
      "valid_from <= valid_to",
      name: "chk_avatar_group_ownership_periods_valid_interval",
    )
  end

  def down
    drop_table :avatar_group_ownership_periods
    remove_check_constraint :avatar_ownership_periods, name: "chk_avatar_ownership_periods_owner_reference"
    remove_column :avatar_ownership_periods, :owner_collective_public_id
    remove_column :avatar_ownership_periods, :owner_surface
  end
end
