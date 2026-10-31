# frozen_string_literal: true
# typed: false

class AppPreference < AppSettingRecord
  include ::PublicId
  include ::PreferenceLifecycle

  ACTIVE_STATUS_ID = AppPreferenceStatus::ACTIVE
  RETIRED_STATUS_ID = AppPreferenceStatus::RETIRED

  belongs_to :app_preference_status,
             foreign_key: :status_id,
             inverse_of: :app_preferences

  has_one :app_preference_cookie, foreign_key: :preference_id, inverse_of: :preference, dependent: :destroy
  has_one :app_preference_consent_receipt,
          foreign_key: :preference_id,
          inverse_of: :preference,
          dependent: :destroy
  has_one :app_preference_browser_binding,
          foreign_key: :preference_id,
          inverse_of: :preference,
          dependent: :destroy
  has_one :app_preference_web_push, foreign_key: :preference_id, inverse_of: :preference, dependent: :destroy
  has_one :app_preference_region, foreign_key: :preference_id, inverse_of: :preference, dependent: :destroy
  has_one :app_preference_timezone, foreign_key: :preference_id, inverse_of: :preference, dependent: :destroy
  has_one :app_preference_language, foreign_key: :preference_id, inverse_of: :preference, dependent: :destroy
  has_one :app_preference_theme, foreign_key: :preference_id, inverse_of: :preference, dependent: :destroy
  has_one :app_preference_currency, foreign_key: :preference_id, inverse_of: :preference, dependent: :destroy
  has_one :app_preference_date_format, foreign_key: :preference_id, inverse_of: :preference, dependent: :destroy
  has_one :app_preference_time_format, foreign_key: :preference_id, inverse_of: :preference, dependent: :destroy
  has_one :app_preference_motion, foreign_key: :preference_id, inverse_of: :preference, dependent: :destroy
  has_one :app_preference_density, foreign_key: :preference_id, inverse_of: :preference, dependent: :destroy
  has_one :app_preference_page_size, foreign_key: :preference_id, inverse_of: :preference, dependent: :destroy
  has_one :app_preference_adult_content_gate,
          foreign_key: :preference_id,
          inverse_of: :preference,
          dependent: :destroy
  has_many :app_preference_chronicles,
           foreign_key: :subject_id,
           inverse_of: :app_preference,
           dependent: :destroy

  attribute :status_id, default: ACTIVE_STATUS_ID
  validates :public_id, presence: true, uniqueness: true
  validates :jti, presence: true, uniqueness: true
  validates :status_id, inclusion: { in: AppPreferenceStatus::DEFAULTS }
  validate :retired_status_cannot_be_reactivated, on: :update

  private

  def retired_status_cannot_be_reactivated
    return unless status_id_in_database == RETIRED_STATUS_ID && status_id == ACTIVE_STATUS_ID

    errors.add(:status_id, :invalid)
  end
end
