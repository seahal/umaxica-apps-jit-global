# frozen_string_literal: true

# Collects expired anonymous preferences only when their audit history is absent.
class PreferenceLifecyclePurger
  BATCH_SIZE = 200
  COM_DEPENDENCIES = %i(
    com_preference_cookie com_preference_consent_receipt com_preference_web_push com_preference_browser_binding
    com_preference_region
    com_preference_timezone com_preference_language com_preference_theme com_preference_currency
    com_preference_date_format com_preference_time_format com_preference_motion com_preference_density
    com_preference_page_size com_preference_chronicles
  ).freeze
  APP_DEPENDENCIES = %i(
    app_preference_cookie app_preference_consent_receipt app_preference_web_push app_preference_browser_binding
    app_preference_region app_preference_timezone app_preference_language app_preference_theme
    app_preference_currency app_preference_date_format app_preference_time_format app_preference_motion
    app_preference_density app_preference_page_size app_preference_adult_content_gate app_preference_chronicles
  ).freeze
  ORG_DEPENDENCIES = %i(
    org_preference_cookie org_preference_consent_receipt org_preference_web_push org_preference_browser_binding
    org_preference_region org_preference_timezone org_preference_language org_preference_theme
    org_preference_currency org_preference_date_format org_preference_time_format org_preference_motion
    org_preference_density org_preference_page_size org_preference_adult_content_gate org_preference_chronicles
  ).freeze

  # Existing COM cleanup tests and teardown use this public association inventory.
  DEPENDENCIES = COM_DEPENDENCIES

  class << self
    public

    def call!
      purge_expired!(ComPreference, ComPreferenceChronicle, COM_DEPENDENCIES) +
        purge_expired!(AppPreference, AppPreferenceChronicle, APP_DEPENDENCIES) +
        purge_expired!(OrgPreference, OrgPreferenceChronicle, ORG_DEPENDENCIES)
    end

    private

    def purge_expired!(preference_class, chronicle_class, dependencies)
      deleted = 0
      preference_class.connection_class_for_self.connected_to(role: :writing) do
        cutoff = preference_class.database_now - PreferenceLifecycle::PURGE_GRACE_PERIOD
        preference_class.where(last_issued_expires_at: ..cutoff).in_batches(of: BATCH_SIZE) do |batch|
          batch.pluck(:id).each do |id|
            deleted += 1 if purge_one!(preference_class, chronicle_class, dependencies, id)
          end
        end
      end
      deleted
    end

    def purge_one!(preference_class, chronicle_class, dependencies, id)
      ChronicleRecord.connected_to(role: :writing) do
        ChronicleRecord.transaction(requires_new: true) do
          chronicle_class.lock_preference_audit_for_purge!
          preference_class.connection_class_for_self.connected_to(role: :writing) do
            preference_class.transaction(requires_new: true) do
              preference = preference_class.lock.preload(*dependencies).find_by(id: id)
              next false unless preference
              next false unless preference.issuance_retention_elapsed?(now: preference_class.database_now)
              next false if chronicle_class.exists?(subject_type: preference_class.name, subject_id: id)
              next false if chronicle_class.exists?(actor_type: preference_class.name, actor_id: id)

              preference.destroy!
              true
            end
          end
        end
      end
    end
  end
end
