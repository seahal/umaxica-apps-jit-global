# frozen_string_literal: true

class ValidateOrgPreferenceStatusForeignKey < ActiveRecord::Migration[8.2]
  FOREIGN_KEY_NAME = "fk_org_preferences_on_status_id"

  def up
    validate_foreign_key(:org_preferences, name: FOREIGN_KEY_NAME)
  end

  def down
    remove_foreign_key(:org_preferences, name: FOREIGN_KEY_NAME)
    add_foreign_key(
      :org_preferences, :org_preference_statuses, column: :status_id,
                                                  name: FOREIGN_KEY_NAME, validate: false,
    )
  end
end
