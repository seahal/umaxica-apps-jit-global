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

  # Fixed IDs - do not modify these values
  NOTHING = 0
  DELETED = 1
  LEGACY_NOTHING = 2
  DEFAULTS = [NOTHING, DELETED, LEGACY_NOTHING].freeze

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
