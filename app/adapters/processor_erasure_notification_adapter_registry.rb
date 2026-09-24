# typed: false
# frozen_string_literal: true

class ProcessorErasureNotificationAdapterRegistry
  class << self
    public

    def fetch(processor_key)
      configured = Rails.application.config.x.processor_erasure_notification_adapters
      configured.fetch(processor_key.to_s, nil)
    end
  end
end
