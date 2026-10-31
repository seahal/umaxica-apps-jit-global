# typed: false
# frozen_string_literal: true

class ComPreferenceWebPush < ComSettingRecord
  belongs_to :preference, class_name: "ComPreference", inverse_of: :com_preference_web_push
  belongs_to :option, class_name: "ComPreferenceWebPushOption", inverse_of: :com_preference_web_pushes

  validates :preference_id, uniqueness: true
  validates :option_id, inclusion: { in: ComPreferenceWebPushOption::DEFAULTS }

  before_validation :set_default_option, on: :create

  private

  def set_default_option
    self.option_id = ComPreferenceWebPushOption::DISABLED if option_id.nil?
  end
end
