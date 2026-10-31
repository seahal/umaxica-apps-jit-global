# frozen_string_literal: true

class AppPreferenceBrowserBinding < AppSettingRecord
  belongs_to :preference, class_name: "AppPreference", inverse_of: :app_preference_browser_binding

  validates :preference_id, uniqueness: true
  validates :digest, presence: true, format: { with: /\A[0-9a-f]{64}\z/ }, length: { is: 64 }
end
