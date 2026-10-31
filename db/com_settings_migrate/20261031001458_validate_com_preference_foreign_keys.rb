# frozen_string_literal: true

class ValidateComPreferenceForeignKeys < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!

  FOREIGN_KEYS = [
    [:com_preference_languages, "fk_com_preference_languages_on_option_id"],
    [:com_preference_regions, "fk_com_preference_regions_on_option_id"],
    [:com_preference_themes, "fk_com_preference_themes_on_option_id"],
    [:com_preference_timezones, "fk_com_preference_timezones_on_option_id"],
    [:com_preferences, "fk_com_preferences_on_status_id"],
    [:com_preference_languages, "fk_rails_0b04f4dc33"],
    [:com_preference_timezones, "fk_rails_2fe4a93e4f"],
    [:com_preference_regions, "fk_rails_da840219b9"],
    [:com_preference_cookies, "fk_rails_e59f447fe4"],
    [:com_preference_themes, "fk_rails_ff9fc0eb33"],
  ].freeze

  def up
    FOREIGN_KEYS.each { |table, name| validate_foreign_key(table, name: name) }
  end

  def down
    # PostgreSQL cannot unvalidate a constraint without dropping it; keep the stronger constraint.
  end
end
