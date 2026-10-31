# frozen_string_literal: true

# Collects expired anonymous com preferences only when their audit history is absent.
class PreferenceLifecyclePurger
  BATCH_SIZE = 200
  DEPENDENCIES = %i(
    com_preference_cookie com_preference_consent_receipt com_preference_web_push com_preference_browser_binding
    com_preference_region
    com_preference_timezone com_preference_language com_preference_theme com_preference_currency
    com_preference_date_format com_preference_time_format com_preference_motion com_preference_density
    com_preference_page_size com_preference_chronicles
  ).freeze

  class << self
    public

    def call!
      deleted = 0
      ComSettingRecord.connected_to(role: :writing) do
        cutoff = ComPreference.database_now - PreferenceLifecycle::PURGE_GRACE_PERIOD
        ComPreference.where(last_issued_expires_at: ..cutoff).in_batches(of: BATCH_SIZE) do |batch|
          batch.pluck(:id).each { |id| deleted += 1 if purge_one!(id) }
        end
      end
      deleted
    end

    private

    def purge_one!(id)
      ChronicleRecord.connected_to(role: :writing) do
        ChronicleRecord.transaction(requires_new: true) do
          ComPreferenceChronicle.lock_preference_audit_for_purge!
          ComSettingRecord.connected_to(role: :writing) do
            ComPreference.transaction(requires_new: true) do
              preference = ComPreference.lock.preload(*DEPENDENCIES).find_by(id: id)
              next false unless preference
              next false unless preference.issuance_retention_elapsed?(now: ComPreference.database_now)
              next false if ComPreferenceChronicle.exists?(subject_id: id)
              next false if ComPreferenceChronicle.exists?(actor_type: "ComPreference", actor_id: id)

              preference.destroy!
              true
            end
          end
        end
      end
    end
  end
end
