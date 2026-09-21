# typed: false
# == Schema Information
#
# Table name: org_preferences
# Database name: org_setting
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
#  index_org_preferences_on_binding_method_id  (binding_method_id)
#  index_org_preferences_on_dbsc_session_id    (dbsc_session_id) UNIQUE
#  index_org_preferences_on_dbsc_status_id     (dbsc_status_id)
#  index_org_preferences_on_jti                (jti) UNIQUE
#  index_org_preferences_on_public_id          (public_id) UNIQUE
#  index_org_preferences_on_purge_eligible_at          (purge_eligible_at)
#  index_org_preferences_on_replaced_by_id     (replaced_by_id)
#  index_org_preferences_on_status_id          (status_id)
#  index_org_preferences_on_token_digest       (token_digest)
#  index_org_preferences_on_used_at            (used_at)
#
# Foreign Keys
#
#  fk_org_preferences_on_binding_method_id  (binding_method_id => org_preference_binding_methods.id)
#  fk_org_preferences_on_dbsc_status_id     (dbsc_status_id => org_preference_dbsc_statuses.id)
#  fk_org_preferences_on_status_id          (status_id => org_preference_statuses.id)
#  fk_rails_...                             (replaced_by_id => org_preferences.id) ON DELETE => nullify
#

# frozen_string_literal: true

class OrgPreference < OrgSettingRecord
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

  DBSC_BINDING_METHOD_CLASS = OrgPreferenceBindingMethod
  DBSC_STATUS_CLASS = OrgPreferenceDbscStatus

  attribute :status_id, default: OrgPreferenceStatus::NOTHING
  attribute :binding_method_id, default: OrgPreferenceBindingMethod::NOTHING
  attribute :dbsc_status_id, default: OrgPreferenceDbscStatus::NOTHING

  belongs_to :org_preference_status,
             foreign_key: :status_id,
             inverse_of: :org_preferences
  belongs_to :org_preference_dbsc_status,
             foreign_key: :dbsc_status_id,
             inverse_of: :org_preferences
  # waht is this?
  belongs_to :org_preference_binding_method,
             foreign_key: :binding_method_id,
             inverse_of: :org_preferences
  # waht is this?
  belongs_to :replaced_by,
             class_name: "OrgPreference"

  has_one :org_preference_cookie,
          foreign_key: :preference_id,
          inverse_of: :preference,
          dependent: :destroy
  has_one :org_preference_region,
          foreign_key: :preference_id,
          inverse_of: :preference,
          dependent: :destroy
  has_one :org_preference_timezone,
          foreign_key: :preference_id,
          inverse_of: :preference,
          dependent: :destroy
  has_one :org_preference_language,
          foreign_key: :preference_id,
          inverse_of: :preference,
          dependent: :destroy
  has_one :org_preference_theme,
          foreign_key: :preference_id,
          inverse_of: :preference,
          dependent: :destroy
  has_one :org_preference_currency,
          foreign_key: :preference_id,
          inverse_of: :preference,
          dependent: :destroy
  has_one :org_preference_date_format,
          foreign_key: :preference_id,
          inverse_of: :preference,
          dependent: :destroy
  has_one :org_preference_time_format,
          foreign_key: :preference_id,
          inverse_of: :preference,
          dependent: :destroy
  has_one :org_preference_motion,
          foreign_key: :preference_id,
          inverse_of: :preference,
          dependent: :destroy
  has_one :org_preference_density,
          foreign_key: :preference_id,
          inverse_of: :preference,
          dependent: :destroy
  has_one :org_preference_page_size,
          foreign_key: :preference_id,
          inverse_of: :preference,
          dependent: :destroy
  has_one :org_preference_adult_content_gate,
          foreign_key: :preference_id,
          inverse_of: :preference,
          dependent: :destroy
  has_many :org_preference_chronicles,
           foreign_key: :subject_id,
           inverse_of: :org_preference,
           dependent: :destroy
  has_many :replacements,
           class_name: "OrgPreference",
           foreign_key: :replaced_by_id,
           inverse_of: :replaced_by,
           dependent: :nullify

  validates :status_id, numericality: { only_integer: true }
  validates :jti, uniqueness: true, allow_nil: true

  before_validation :default_replaced_by_to_self, on: :create
  after_create :persist_self_replacement

  def adult_content_gate
    org_preference_adult_content_gate&.option&.name || "nothing"
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
