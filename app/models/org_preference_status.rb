# frozen_string_literal: true
# typed: false

# == Schema Information
#
# Table name: org_preference_statuses
# Database name: org_setting
#
#  id :bigint           not null, primary key
#

class OrgPreferenceStatus < OrgSettingRecord
  include ReferenceRecord

  RETIRED = 1
  ACTIVE = 2

  DEFAULTS = [RETIRED, ACTIVE].freeze

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
