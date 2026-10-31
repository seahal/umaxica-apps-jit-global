# frozen_string_literal: true

class OrgPreferenceWebPush < OrgSettingRecord
  belongs_to :preference, class_name: "OrgPreference", inverse_of: :org_preference_web_push
  belongs_to :option, class_name: "OrgPreferenceWebPushOption", inverse_of: :org_preference_web_pushes

  validates :preference_id, uniqueness: true
  validates :option_id, inclusion: { in: OrgPreferenceWebPushOption::DEFAULTS }

  before_validation :set_default_option, on: :create

  private

  def set_default_option
    self.option_id = OrgPreferenceWebPushOption::DISABLED if option_id.nil?
  end
end
