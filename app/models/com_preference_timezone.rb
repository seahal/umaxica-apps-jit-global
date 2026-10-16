# frozen_string_literal: true
# typed: false

# == Schema Information
#
# Table name: com_preference_timezones
# Database name: com_setting
#
#  id            :bigint           not null, primary key
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  option_id     :bigint           not null
#  preference_id :bigint           not null
#
# Indexes
#
#  index_com_preference_timezones_on_option_id      (option_id)
#  index_com_preference_timezones_on_preference_id  (preference_id) UNIQUE
#
# Foreign Keys
#
#  fk_com_preference_timezones_on_option_id  (option_id => com_preference_timezone_options.id)
#  fk_rails_...                              (preference_id => com_preferences.id)
#

class ComPreferenceTimezone < ComSettingRecord
  belongs_to :preference, class_name: "ComPreference", inverse_of: :com_preference_timezone
  belongs_to :option,
             class_name: "ComPreferenceTimezoneOption",
             inverse_of: :com_preference_timezones
  validates :preference_id, uniqueness: true
  before_validation :set_option_id

  private

  def set_option_id
    self.option_id ||= ComPreferenceTimezoneOption::ASIA_TOKYO
  end
end
