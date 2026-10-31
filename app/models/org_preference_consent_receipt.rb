# frozen_string_literal: true

class OrgPreferenceConsentReceipt < OrgSettingRecord
  belongs_to :preference, class_name: "OrgPreference", inverse_of: :org_preference_consent_receipt

  validates :preference_id, uniqueness: true
  validates :version, :recorded_at, presence: true
end
