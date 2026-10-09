# typed: false
# == Schema Information
#
# Table name: org_preference_statuses
# Database name: org_setting
#
#  id :bigint           not null, primary key
#

# frozen_string_literal: true

class OrgPreferenceStatus < OrgSettingRecord
  include ReferenceRecord

  # Fixed IDs - do not modify these values
  DELETED = 1
  NOTHING = 2

  DEFAULTS = [DELETED, NOTHING].freeze

  has_many :org_preferences,
           class_name: "OrgPreference",
           foreign_key: "status_id",
           primary_key: "id",
           inverse_of: :org_preference_status,
           dependent: :restrict_with_error

  def self.ensure_defaults!
    insert_missing_fixed_ids!(DEFAULTS)
  end
end
