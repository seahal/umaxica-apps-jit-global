# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: visitor_preference_theme_options
# Database name: com_principal
#
#  id :bigint           not null, primary key
#
# Indexes
#
#  index_visitor_preference_theme_options_on_id  (id) UNIQUE
#
class VisitorPreferenceThemeOption < ComPrincipalRecord
  # Fixed IDs - do not modify these values
  SYSTEM = 0
  LIGHT = 1
  DARK = 2
  LEGACY_SYSTEM = 3
  DEFAULTS = [SYSTEM, LIGHT, DARK, LEGACY_SYSTEM].freeze

  has_many :visitor_preference_themes,
           class_name: "VisitorPreferenceTheme",
           foreign_key: :option_id,
           inverse_of: :option,
           dependent: :restrict_with_error

  self.primary_key = :id

  # Unique indexes that include the primary key back composite references; checked only for an explicit id.
  validates :id, uniqueness: true, allow_nil: true, if: :will_save_change_to_id?

  def self.ensure_defaults!
    insert_missing_fixed_ids!(DEFAULTS)
  end

  def name
    case id
    when SYSTEM, LEGACY_SYSTEM then "system"
    when LIGHT then "light"
    when DARK then "dark"
    end
  end
end
