# frozen_string_literal: true

class ComPreferenceConsentReceipt < ComSettingRecord
  belongs_to :preference, class_name: "ComPreference", inverse_of: :com_preference_consent_receipt

  validates :preference_id, uniqueness: true
  validates :version, :recorded_at, presence: true
end
