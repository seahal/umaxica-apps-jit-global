# typed: false
# == Schema Information
#
# Table name: com_preferences
# Database name: com_setting
#
#  id                       :bigint           not null, primary key
#  dbsc_challenge           :text
#  dbsc_challenge_issued_at :datetime
#  dbsc_public_key          :jsonb
#  discard_at             :datetime         default(Infinity), not null
#  explicit_fields          :jsonb            not null
#  jti                      :string
#  purge_eligible_at                :datetime         default(Infinity), not null
#  token_digest             :binary
#  used_at                  :datetime
#  created_at               :datetime         not null
#  updated_at               :datetime         not null
#  binding_method_id        :bigint           default(0), not null
#  dbsc_session_id          :string
#  dbsc_status_id           :bigint           default(0), not null
#  public_id                :string           not null
#  replaced_by_id           :bigint
#  status_id                :bigint           default(2), not null
#
# Indexes
#
#  index_com_preferences_on_binding_method_id  (binding_method_id)
#  index_com_preferences_on_dbsc_session_id    (dbsc_session_id) UNIQUE
#  index_com_preferences_on_dbsc_status_id     (dbsc_status_id)
#  index_com_preferences_on_jti                (jti) UNIQUE
#  index_com_preferences_on_public_id          (public_id) UNIQUE
#  index_com_preferences_on_purge_eligible_at          (purge_eligible_at)
#  index_com_preferences_on_replaced_by_id     (replaced_by_id)
#  index_com_preferences_on_status_id          (status_id)
#  index_com_preferences_on_token_digest       (token_digest)
#  index_com_preferences_on_used_at            (used_at)
#
# Foreign Keys
#
#  fk_com_preferences_on_binding_method_id  (binding_method_id => com_preference_binding_methods.id)
#  fk_com_preferences_on_dbsc_status_id     (dbsc_status_id => com_preference_dbsc_statuses.id)
#  fk_com_preferences_on_status_id          (status_id => com_preference_statuses.id)
#  fk_rails_...                             (replaced_by_id => com_preferences.id) ON DELETE => nullify
#

# frozen_string_literal: true

class ComPreference < ComSettingRecord
  include Retainable
  include ::PublicId
  include ::SingleUseToken
  include ::PreferenceResettable
  include ::PreferenceExplicitFields
  include ::DbscBindable

  self.belongs_to_required_by_default = false

  # A preference token is "expired" exactly when it has been discarded, so the
  # generic token vocabulary reads expires_at while Retainable owns the column.
  #
  # The alias leaks Retainable::SENTINEL (Float::INFINITY) for a record that has
  # never been discarded, because that is the column default. It is a Float, not
  # a Time, so every reader must reject it before treating the value as an
  # expiry -- see PreferenceWebCookieEndpoint#refresh_token_expires_at and
  # #consented_buffer_expires_at, which both guard with `!expires_at.is_a?(Float)`.
  # A new caller that forgets this guard writes an infinite cookie lifetime.
  alias_attribute :expires_at, :discard_at

  DBSC_BINDING_METHOD_CLASS = ComPreferenceBindingMethod
  DBSC_STATUS_CLASS = ComPreferenceDbscStatus

  attribute :status_id, default: ComPreferenceStatus::NOTHING

  belongs_to :com_preference_status,
             foreign_key: :status_id,
             inverse_of: :com_preferences
  belongs_to :com_preference_binding_method,
             foreign_key: :binding_method_id,
             inverse_of: :com_preferences
  belongs_to :com_preference_dbsc_status,
             foreign_key: :dbsc_status_id,
             inverse_of: :com_preferences

  has_one :com_preference_cookie,
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
           dependent: :destroy
  belongs_to :replaced_by,
             class_name: "ComPreference"
  has_many :replacements,
           class_name: "ComPreference",
           foreign_key: :replaced_by_id,
           inverse_of: :replaced_by,
           dependent: :nullify
  validates :status_id, numericality: { only_integer: true }
  validates :jti, uniqueness: true, allow_nil: true
  attribute :binding_method_id, default: ComPreferenceBindingMethod::NOTHING
  attribute :dbsc_status_id, default: ComPreferenceDbscStatus::NOTHING

  before_validation :default_replaced_by_to_self, on: :create
  after_create :persist_self_replacement

  def adult_content_gate
    com_preference_adult_content_gate&.option&.name || "nothing"
  end

  private

  def default_replaced_by_to_self
    self.replaced_by ||= self
  end

  def persist_self_replacement
    # rubocop:disable Rails/SkipsModelValidations
    update_column(:replaced_by_id, id) if replaced_by_id.blank?
    # rubocop:enable Rails/SkipsModelValidations
  end
end
