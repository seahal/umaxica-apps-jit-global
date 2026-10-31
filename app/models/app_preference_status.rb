# frozen_string_literal: true
# typed: false

# == Schema Information
#
# Table name: app_preference_statuses
# Database name: app_setting
#
#  id :bigint           not null, primary key
#

class AppPreferenceStatus < AppSettingRecord
  include ReferenceRecord

  ACTIVE = 0
  RETIRED = 1
  DEFAULTS = [ACTIVE, RETIRED].freeze

  has_many :app_preferences,
           class_name: "AppPreference",
           foreign_key: "status_id",
           primary_key: "id",
           inverse_of: :app_preference_status,
           dependent: :restrict_with_error

  def self.ensure_defaults!
    insert_missing_fixed_ids!(DEFAULTS)
  end
end
