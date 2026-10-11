# frozen_string_literal: true

class AddAvatarOwnershipPeriodTemporalExclusion < ActiveRecord::Migration[8.2]
  CHECK_NAME = "chk_avatar_ownership_periods_strict_interval"
  EXCLUSION_NAME = "excl_avatar_ownership_periods_non_overlapping"

  def up
    enable_extension("btree_gist") unless extension_enabled?("btree_gist")
    add_check_constraint(
      :avatar_ownership_periods,
      "valid_from < valid_to",
      name: CHECK_NAME,
      validate: false,
    )
    # PostgreSQL has no non-blocking Rails API for creating this GiST exclusion constraint. The
    # migration is explicitly safety-assured because the temporal invariant is the approved DB
    # authority; existing rows are checked before the migration is recorded.
    safety_assured do
      add_exclusion_constraint(
        :avatar_ownership_periods,
        "avatar_id WITH =, tstzrange(valid_from, valid_to, '[)') WITH &&",
        using: :gist,
        name: EXCLUSION_NAME,
      )
    end
  end

  def down
    remove_exclusion_constraint(:avatar_ownership_periods, name: EXCLUSION_NAME)
    remove_check_constraint(:avatar_ownership_periods, name: CHECK_NAME)
  end
end
