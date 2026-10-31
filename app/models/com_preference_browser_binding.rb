# typed: false
# frozen_string_literal: true

class ComPreferenceBrowserBinding < ComSettingRecord
  belongs_to :preference, class_name: "ComPreference", inverse_of: :com_preference_browser_binding

  validates :preference_id, uniqueness: true
  validates :digest, presence: true, format: { with: /\A[0-9a-f]{64}\z/ }, length: { is: 64 }
end
