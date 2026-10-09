# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: visitor_preference_language_options
# Database name: com_principal
#
#  id :bigint           not null, primary key
#
# Indexes
#
#  index_visitor_preference_language_options_on_id  (id) UNIQUE
#
class VisitorPreferenceLanguageOption < ComPrincipalRecord
  include ReferenceRecord

  NOTHING = 0
  JA = 1
  EN = 2

  DEFAULTS = [NOTHING, JA, EN].freeze

  has_many :visitor_preference_languages,
           class_name: "VisitorPreferenceLanguage",
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
