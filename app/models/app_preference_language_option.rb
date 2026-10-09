# typed: false
# == Schema Information
#
# Table name: app_preference_language_options
# Database name: app_setting
#
#  id :bigint           not null, primary key
#

# frozen_string_literal: true

class AppPreferenceLanguageOption < AppSettingRecord
  # Fixed IDs - do not modify these values
  JA = 1
  EN = 2
  DEFAULTS = [JA, EN].freeze

  has_many :app_preference_languages,
           class_name: "AppPreferenceLanguage",
           foreign_key: :option_id,
           inverse_of: :option,
           dependent: :restrict_with_error

  self.primary_key = :id

  def self.ensure_defaults!
    insert_missing_fixed_ids!(DEFAULTS)
  end

  def name
    case id
    when JA then "ja"
    when EN then "en"
    end
  end
end
