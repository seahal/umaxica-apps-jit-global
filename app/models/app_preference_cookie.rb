# typed: false
# == Schema Information
#
# Table name: app_preference_cookies
# Database name: app_setting
#
#  id              :bigint           not null, primary key
#  consent_version :uuid
#  consented       :boolean          default(FALSE), not null
#  consented_at    :datetime
#  functional      :boolean          default(FALSE), not null
#  performant      :boolean          default(FALSE), not null
#  targetable      :boolean          default(FALSE), not null
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  preference_id   :bigint           not null
#
# Indexes
#
#  index_app_preference_cookies_on_preference_id  (preference_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (preference_id => app_preferences.id)
#

# frozen_string_literal: true

class AppPreferenceCookie < AppSettingRecord
  belongs_to :preference,
             class_name: "AppPreference",
             inverse_of: :app_preference_cookie

  validates :preference_id, uniqueness: true
  validates :targetable, inclusion: { in: [true, false] }
  validates :performant, inclusion: { in: [true, false] }
  validates :functional, inclusion: { in: [true, false] }
  validates :consented, inclusion: { in: [true, false] }

  after_initialize :set_defaults

  private

  def set_defaults
    return unless new_record?

    self.targetable = false if targetable.nil?
    self.performant = false if performant.nil?
    self.functional = false if functional.nil?
    self.consented = false if consented.nil?
  end
end
