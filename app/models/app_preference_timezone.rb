# frozen_string_literal: true
# typed: false

# == Schema Information
#
# Table name: app_preference_timezones
# Database name: app_setting
#
#  id            :bigint           not null, primary key
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  option_id     :bigint           not null
#  preference_id :bigint           not null
#
# Indexes
#
#  index_app_preference_timezones_on_option_id      (option_id)
#  index_app_preference_timezones_on_preference_id  (preference_id) UNIQUE
#
# Foreign Keys
#
#  fk_app_preference_timezones_on_option_id  (option_id => app_preference_timezone_options.id)
#  fk_rails_...                              (preference_id => app_preferences.id)
#

class AppPreferenceTimezone < AppSettingRecord
  belongs_to :preference, class_name: "AppPreference", inverse_of: :app_preference_timezone
  belongs_to :option,
             class_name: "AppPreferenceTimezoneOption",
             inverse_of: :app_preference_timezones
  validates :preference_id, uniqueness: true
  before_validation :set_option_id

  private

  def set_option_id
    self.option_id ||= AppPreferenceTimezoneOption::ASIA_TOKYO
  end
end
