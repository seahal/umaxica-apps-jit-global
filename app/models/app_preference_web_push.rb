# frozen_string_literal: true

class AppPreferenceWebPush < AppSettingRecord
  belongs_to :preference, class_name: "AppPreference", inverse_of: :app_preference_web_push
  belongs_to :option, class_name: "AppPreferenceWebPushOption", inverse_of: :app_preference_web_pushes

  validates :preference_id, uniqueness: true
  validates :option_id, inclusion: { in: AppPreferenceWebPushOption::DEFAULTS }

  before_validation :set_default_option, on: :create

  private

  def set_default_option
    self.option_id = AppPreferenceWebPushOption::DISABLED if option_id.nil?
  end
end
