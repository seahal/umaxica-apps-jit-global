# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: operator_preference_theme_options
# Database name: org_principal
#
#  id :bigint           not null, primary key
#
class OperatorPreferenceThemeOption < OrgPrincipalRecord
  include ReferenceRecord

  # Fixed IDs - do not modify these values
  NOTHING = 0
  LIGHT = 1
  DARK = 2
  SYSTEM = 3

  DEFAULTS = [NOTHING, LIGHT, DARK, SYSTEM].freeze

  has_many :staff_preference_themes,
           class_name: "OperatorPreferenceTheme",
           foreign_key: :option_id,
           inverse_of: :option,
           dependent: :restrict_with_error
  has_many :operator_preference_themes,
           class_name: "OperatorPreferenceTheme",
           foreign_key: :option_id,
           inverse_of: :option,
           dependent: :restrict_with_error

  def self.ensure_defaults!
    insert_missing_fixed_ids!(DEFAULTS)
  end

  def name
    case id
    when LIGHT then "light"
    when DARK then "dark"
    when SYSTEM then "system"
    end
  end
end
