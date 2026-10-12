# frozen_string_literal: true

class AddOrgPreferencePublicIdCapacityCheck < ActiveRecord::Migration[8.2]
  TABLE = :org_preferences
  CONSTRAINT = "org_preferences_public_id_max_length"
  EXPRESSION = "char_length(public_id) <= 25"

  def up
    add_check_constraint(TABLE, EXPRESSION, name: CONSTRAINT, validate: false)
  end

  def down
    remove_check_constraint(TABLE, name: CONSTRAINT)
  end
end
