# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: client_preferences
# Database name: app_principal
#
#  id              :bigint           not null, primary key
#  client_id       :bigint           not null
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  public_id        :string(21)       not null
#  explicit_fields :jsonb            default([]), not null
#  status_id        :bigint           default(0), not null
#
# Indexes
#
#  index_client_preferences_on_public_id       (public_id) UNIQUE
#  index_client_preferences_on_active_client_id (client_id) UNIQUE WHERE status_id = 0
#
# Foreign Keys
#
#  fk_client_preferences_on_client_id  (client_id => clients.id)
#  fk_client_preferences_on_status_id  (status_id => client_preference_statuses.id)
#
class ClientPreference < AppPrincipalRecord
  include ::PublicId
  include ::PreferenceExplicitFields
  include ::ActorPreferenceExplicitDisplay

  ACTIVE_STATUS_ID = ClientPreferenceStatus::ACTIVE
  RETIRED_STATUS_ID = ClientPreferenceStatus::RETIRED

  DESTROY_DEPENDENT_ASSOCIATIONS = %i(
    client_preference_language client_preference_timezone client_preference_region client_preference_theme
    client_preference_currency client_preference_date_format client_preference_time_format
    client_preference_motion client_preference_density client_preference_page_size
    client_preference_adult_content_gate
  ).freeze

  belongs_to :client, class_name: "Client", inverse_of: :client_preference
  belongs_to :client_preference_status, foreign_key: :status_id, inverse_of: :client_preferences

  has_one :client_preference_language, class_name: "ClientPreferenceLanguage",
                                       foreign_key: :preference_id,
                                       inverse_of: :preference,
                                       dependent: :destroy
  has_one :client_preference_timezone, class_name: "ClientPreferenceTimezone",
                                       foreign_key: :preference_id,
                                       inverse_of: :preference,
                                       dependent: :destroy
  has_one :client_preference_region, class_name: "ClientPreferenceRegion",
                                     foreign_key: :preference_id,
                                     inverse_of: :preference,
                                     dependent: :destroy
  has_one :client_preference_theme, class_name: "ClientPreferenceTheme",
                                    foreign_key: :preference_id,
                                    inverse_of: :preference,
                                    dependent: :destroy
  has_one :client_preference_currency,
          foreign_key: :preference_id,
          inverse_of: :preference,
          dependent: :destroy
  has_one :client_preference_date_format,
          foreign_key: :preference_id,
          inverse_of: :preference,
          dependent: :destroy
  has_one :client_preference_time_format,
          foreign_key: :preference_id,
          inverse_of: :preference,
          dependent: :destroy
  has_one :client_preference_motion,
          foreign_key: :preference_id,
          inverse_of: :preference,
          dependent: :destroy
  has_one :client_preference_density,
          foreign_key: :preference_id,
          inverse_of: :preference,
          dependent: :destroy
  has_one :client_preference_page_size,
          foreign_key: :preference_id,
          inverse_of: :preference,
          dependent: :destroy
  has_one :client_preference_adult_content_gate,
          foreign_key: :preference_id,
          inverse_of: :preference,
          dependent: :destroy

  attribute :status_id, default: ACTIVE_STATUS_ID
  validates :status_id, inclusion: { in: ClientPreferenceStatus::DEFAULTS }
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
    when "language" then client_preference_language
    when "timezone" then client_preference_timezone
    when "region" then client_preference_region
    when "theme" then client_preference_theme
    when "currency" then client_preference_currency
    when "date_format" then client_preference_date_format
    when "time_format" then client_preference_time_format
    when "motion" then client_preference_motion
    when "density" then client_preference_density
    when "page_size" then client_preference_page_size
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
