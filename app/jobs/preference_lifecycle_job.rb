# frozen_string_literal: true

class PreferenceLifecycleJob < ApplicationJob
  queue_as :retention

  public

  def perform
    if FeatureFlags.enabled?(RetentionPurgeJob::FEATURE_NAME)
      Rails.logger.warn(JitLogEvent.format("preference.lifecycle.purge_suspended"))
      return 0
    end

    PreferenceLifecyclePurger.call!
  end
end
