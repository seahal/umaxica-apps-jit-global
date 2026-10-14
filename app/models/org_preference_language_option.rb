# frozen_string_literal: true
# typed: false
# == Schema Information
#
# Table name: org_preference_language_options
# Database name: org_setting
#
#  id :bigint           not null, primary key
#


class OrgPreferenceLanguageOption < OrgSettingRecord
  include ReferenceRecord

  # Fixed IDs - do not modify these values
  JA = 1
  EN = 2

  DEFAULTS = [JA, EN].freeze

  has_many :org_preference_languages,
           class_name: "OrgPreferenceLanguage",
           foreign_key: :option_id,
           inverse_of: :option,
           dependent: :restrict_with_error

  def self.ensure_defaults!
    insert_missing_fixed_ids!(DEFAULTS)
  end

  def name
    case id
    when JA then "ja"
    when EN then "en"
    end
  end

  self.primary_key = :id
end
