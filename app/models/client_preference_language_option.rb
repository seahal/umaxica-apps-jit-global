# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: client_preference_language_options
# Database name: app_principal
#
#  id :bigint           not null, primary key
#
class ClientPreferenceLanguageOption < AppPrincipalRecord
  include ReferenceRecord

  # Fixed IDs - do not modify these values
  NOTHING = 0
  JA = 1
  EN = 2

  DEFAULTS = [JA, EN].freeze

  has_many :client_preference_languages,
           class_name: "ClientPreferenceLanguage",
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
