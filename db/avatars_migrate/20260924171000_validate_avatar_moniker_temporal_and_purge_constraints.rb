# frozen_string_literal: true

class ValidateAvatarMonikerTemporalAndPurgeConstraints < ActiveRecord::Migration[8.2]
  def up
    validate_check_constraint(:avatar_monikers, name: "chk_avatar_monikers_valid_interval")
    validate_foreign_key(:avatar_monikers, :avatars)
  end

  def down
    # PostgreSQL constraints cannot be returned to NOT VALID after validation.
  end
end
