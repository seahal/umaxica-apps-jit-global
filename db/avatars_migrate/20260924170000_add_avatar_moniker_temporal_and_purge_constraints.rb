# frozen_string_literal: true

class AddAvatarMonikerTemporalAndPurgeConstraints < ActiveRecord::Migration[8.2]
  def up
    add_check_constraint(
      :avatar_monikers,
      "valid_from <= valid_to",
      name: "chk_avatar_monikers_valid_interval",
      validate: false,
    )

    remove_foreign_key(:avatar_monikers, column: :avatar_id)
    add_foreign_key(
      :avatar_monikers,
      :avatars,
      column: :avatar_id,
      on_delete: :cascade,
      validate: false,
    )
  end

  def down
    remove_foreign_key(:avatar_monikers, column: :avatar_id)
    add_foreign_key(:avatar_monikers, :avatars, column: :avatar_id, validate: false)
    remove_check_constraint(:avatar_monikers, name: "chk_avatar_monikers_valid_interval")
  end
end
