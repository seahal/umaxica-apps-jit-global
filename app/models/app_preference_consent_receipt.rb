# frozen_string_literal: true

class AppPreferenceConsentReceipt < AppSettingRecord
  belongs_to :preference, class_name: "AppPreference", inverse_of: :app_preference_consent_receipt

  validates :preference_id, uniqueness: true
  validates :version, :recorded_at, presence: true
end
