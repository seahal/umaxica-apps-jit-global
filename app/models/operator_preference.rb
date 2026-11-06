# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: operator_preferences
# Database name: org_principal
#
#  id              :bigint           not null, primary key
#  operator_id     :bigint           not null
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  public_id       :string(21)       not null
#  explicit_fields :jsonb            default([]), not null
#  status_id       :bigint           default(0), not null
#
# Indexes
#
#  index_operator_preferences_on_public_id  (public_id) UNIQUE
#  index_operator_preferences_on_active_operator_id (operator_id) UNIQUE WHERE status_id = 0
#
# Foreign Keys
#
#  fk_operator_preferences_on_operator_id  (operator_id => operators.id)
#  fk_operator_preferences_on_status_id    (status_id => operator_preference_statuses.id)
#
class OperatorPreference < OrgPrincipalRecord
  include ::PublicId
  include ::PreferenceExplicitFields
  include ::ActorPreferenceExplicitDisplay

  ACTIVE_STATUS_ID = OperatorPreferenceStatus::ACTIVE
  RETIRED_STATUS_ID = OperatorPreferenceStatus::RETIRED

  DESTROY_DEPENDENT_ASSOCIATIONS = %i(
    operator_preference_language operator_preference_timezone operator_preference_region operator_preference_theme
    operator_preference_currency operator_preference_date_format operator_preference_time_format
    operator_preference_motion operator_preference_density operator_preference_page_size
    operator_preference_adult_content_gate
  ).freeze

  belongs_to :operator, inverse_of: :operator_preference
  belongs_to :operator_preference_status, foreign_key: :status_id, inverse_of: :operator_preferences

  has_one :operator_preference_language, class_name: "OperatorPreferenceLanguage", foreign_key: :preference_id,
                                         inverse_of: :preference,
                                         dependent: :destroy
  has_one :operator_preference_timezone, class_name: "OperatorPreferenceTimezone", foreign_key: :preference_id,
                                         inverse_of: :preference,
                                         dependent: :destroy
  has_one :operator_preference_region, class_name: "OperatorPreferenceRegion", foreign_key: :preference_id,
                                       inverse_of: :preference,
                                       dependent: :destroy
  has_one :operator_preference_theme, class_name: "OperatorPreferenceTheme", foreign_key: :preference_id,
                                      inverse_of: :preference,
                                      dependent: :destroy
  has_one :operator_preference_currency,
          foreign_key: :preference_id,
          inverse_of: :preference,
          dependent: :destroy
  has_one :operator_preference_date_format,
          foreign_key: :preference_id,
          inverse_of: :preference,
          dependent: :destroy
  has_one :operator_preference_time_format,
          foreign_key: :preference_id,
          inverse_of: :preference,
          dependent: :destroy
  has_one :operator_preference_motion,
          foreign_key: :preference_id,
          inverse_of: :preference,
          dependent: :destroy
  has_one :operator_preference_density,
          foreign_key: :preference_id,
          inverse_of: :preference,
          dependent: :destroy
  has_one :operator_preference_page_size,
          foreign_key: :preference_id,
          inverse_of: :preference,
          dependent: :destroy
  has_one :operator_preference_adult_content_gate,
          foreign_key: :preference_id,
          inverse_of: :preference,
          dependent: :destroy

  attribute :status_id, default: ACTIVE_STATUS_ID
  validates :status_id, inclusion: { in: OperatorPreferenceStatus::DEFAULTS }
  validates :public_id, presence: true, uniqueness: true
  validate :retired_status_cannot_be_reactivated, on: :update
  before_destroy :preload_dependent_associations, prepend: true

  def retire!
    with_lock do
      raise PreferenceLifecycle::InvalidTransition, "only an active Preference can be retired" unless
        status_id == ACTIVE_STATUS_ID

      update!(status_id: RETIRED_STATUS_ID)
    end
  end

  private

  def actor_preference_child_for(field)
    case field
    when "language" then operator_preference_language
    when "timezone" then operator_preference_timezone
    when "region" then operator_preference_region
    when "theme" then operator_preference_theme
    when "currency" then operator_preference_currency
    when "date_format" then operator_preference_date_format
    when "time_format" then operator_preference_time_format
    when "motion" then operator_preference_motion
    when "density" then operator_preference_density
    when "page_size" then operator_preference_page_size
    else raise ArgumentError, "unsupported actor preference field: #{field.inspect}"
    end
  end

  def preload_dependent_associations
    ActiveRecord::Associations::Preloader.new(
      records: [self], associations: DESTROY_DEPENDENT_ASSOCIATIONS,
    ).call
  end

  def retired_status_cannot_be_reactivated
    return unless status_id_in_database == RETIRED_STATUS_ID && status_id == ACTIVE_STATUS_ID

    errors.add(:status_id, :invalid)
  end
end
