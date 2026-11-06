# frozen_string_literal: true
# typed: false

class OrgPreference < OrgSettingRecord
  include ::PublicId
  include ::PreferenceLifecycle

  ACTIVE_STATUS_ID = OrgPreferenceStatus::ACTIVE
  RETIRED_STATUS_ID = OrgPreferenceStatus::RETIRED

  belongs_to :org_preference_status,
             foreign_key: :status_id,
             inverse_of: :org_preferences

  has_one :org_preference_cookie, foreign_key: :preference_id, inverse_of: :preference, dependent: :destroy
  has_one :org_preference_consent_receipt,
          foreign_key: :preference_id,
          inverse_of: :preference,
          dependent: :destroy
  has_one :org_preference_browser_binding,
          foreign_key: :preference_id,
          inverse_of: :preference,
          dependent: :destroy
  has_one :org_preference_web_push, foreign_key: :preference_id, inverse_of: :preference, dependent: :destroy
  has_one :org_preference_region, foreign_key: :preference_id, inverse_of: :preference, dependent: :destroy
  has_one :org_preference_timezone, foreign_key: :preference_id, inverse_of: :preference, dependent: :destroy
  has_one :org_preference_language, foreign_key: :preference_id, inverse_of: :preference, dependent: :destroy
  has_one :org_preference_theme, foreign_key: :preference_id, inverse_of: :preference, dependent: :destroy
  has_one :org_preference_currency, foreign_key: :preference_id, inverse_of: :preference, dependent: :destroy
  has_one :org_preference_date_format, foreign_key: :preference_id, inverse_of: :preference, dependent: :destroy
  has_one :org_preference_time_format, foreign_key: :preference_id, inverse_of: :preference, dependent: :destroy
  has_one :org_preference_motion, foreign_key: :preference_id, inverse_of: :preference, dependent: :destroy
  has_one :org_preference_density, foreign_key: :preference_id, inverse_of: :preference, dependent: :destroy
  has_one :org_preference_page_size, foreign_key: :preference_id, inverse_of: :preference, dependent: :destroy
  has_one :org_preference_adult_content_gate,
          foreign_key: :preference_id,
          inverse_of: :preference,
          dependent: :destroy
  has_many :org_preference_chronicles, -> { where(subject_type: "OrgPreference") },
           foreign_key: :subject_id,
           inverse_of: :org_preference,
           dependent: :restrict_with_exception

  attribute :status_id, default: ACTIVE_STATUS_ID
  validates :public_id, presence: true, uniqueness: true
  validates :jti, presence: true, uniqueness: true
  validates :last_issued_at, :last_issued_expires_at, presence: true
  validates :status_id, inclusion: { in: OrgPreferenceStatus::DEFAULTS }
  validate :retired_status_cannot_be_reactivated, on: :update

  private

  def retired_status_cannot_be_reactivated
    return unless status_id_in_database == RETIRED_STATUS_ID && status_id == ACTIVE_STATUS_ID

    errors.add(:status_id, :invalid)
  end
end
