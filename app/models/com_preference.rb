# frozen_string_literal: true
# typed: false

# == Schema Information
#
# Table name: com_preferences
# Database name: com_setting
#
#  id                       :bigint           not null, primary key
#  jti                      :string           not null
#  created_at               :datetime         not null
#  updated_at               :datetime         not null
#  public_id                :string           not null
#  status_id                :bigint           default(2), not null
#
# Indexes
#
#  index_com_preferences_on_jti                (jti) UNIQUE
#  index_com_preferences_on_public_id          (public_id) UNIQUE
#  index_com_preferences_on_status_id          (status_id)
#
# Foreign Keys
#
#  fk_com_preferences_on_status_id          (status_id => com_preference_statuses.id)
#

class ComPreference < ComSettingRecord
  include ::PublicId
  include ::PreferenceResettable
  include ::PreferenceLifecycle

  self.belongs_to_required_by_default = false

  ACTIVE_STATUS_ID = ComPreferenceStatus::ACTIVE
  RETIRED_STATUS_ID = ComPreferenceStatus::RETIRED

  attribute :status_id, default: ComPreferenceStatus::ACTIVE

  belongs_to :com_preference_status,
             foreign_key: :status_id,
             inverse_of: :com_preferences

  has_one :com_preference_cookie,
          foreign_key: :preference_id,
          inverse_of: :preference,
          dependent: :destroy
  has_one :com_preference_consent_receipt,
          foreign_key: :preference_id,
          inverse_of: :preference,
          dependent: :destroy
  has_one :com_preference_web_push,
          foreign_key: :preference_id,
          inverse_of: :preference,
          dependent: :destroy
  has_one :com_preference_browser_binding,
          foreign_key: :preference_id,
          inverse_of: :preference,
          dependent: :destroy
  has_one :com_preference_region,
          foreign_key: :preference_id,
          inverse_of: :preference,
          dependent: :destroy
  has_one :com_preference_timezone,
          foreign_key: :preference_id,
          inverse_of: :preference,
          dependent: :destroy
  has_one :com_preference_language,
          foreign_key: :preference_id,
          inverse_of: :preference,
          dependent: :destroy
  has_one :com_preference_theme,
          foreign_key: :preference_id,
          inverse_of: :preference,
          dependent: :destroy
  has_one :com_preference_currency,
          foreign_key: :preference_id,
          inverse_of: :preference,
          dependent: :destroy
  has_one :com_preference_date_format,
          foreign_key: :preference_id,
          inverse_of: :preference,
          dependent: :destroy
  has_one :com_preference_time_format,
          foreign_key: :preference_id,
          inverse_of: :preference,
          dependent: :destroy
  has_one :com_preference_motion,
          foreign_key: :preference_id,
          inverse_of: :preference,
          dependent: :destroy
  has_one :com_preference_density,
          foreign_key: :preference_id,
          inverse_of: :preference,
          dependent: :destroy
  has_one :com_preference_page_size,
          foreign_key: :preference_id,
          inverse_of: :preference,
          dependent: :destroy
  has_one :com_preference_adult_content_gate,
          foreign_key: :preference_id,
          inverse_of: :preference,
          dependent: :destroy
  has_many :com_preference_chronicles,
           foreign_key: :subject_id,
           inverse_of: :com_preference,
           dependent: :restrict_with_exception
  validates :status_id, numericality: { only_integer: true }
  validates :status_id, inclusion: { in: ComPreferenceStatus::DEFAULTS }
  validates :jti, presence: true, uniqueness: true
  validates :last_issued_at, :last_issued_expires_at, presence: true
  validate :retired_status_cannot_be_reactivated, on: :update

  def adult_content_gate
    com_preference_adult_content_gate&.option&.name || "nothing"
  end

  private

  def retired_status_cannot_be_reactivated
    return unless status_id_in_database == ComPreferenceStatus::RETIRED && status_id == ComPreferenceStatus::ACTIVE

    errors.add(:status_id, :invalid)
  end
end
