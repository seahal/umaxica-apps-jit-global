# typed: false
# frozen_string_literal: true

# Retries applying a committed Zenith identity stop event to its OP (R5-WU06). The applier is
# idempotent on the event ID, so a retry after a partial failure or a duplicate enqueue is safe.
class OpIdentityEventDeliveryJob < ApplicationJob
  queue_as :default

  EVENT_CLASSES = %w(AppIdentityAuthenticationEvent ComIdentityAuthenticationEvent
                     OrgIdentityAuthenticationEvent).freeze

  retry_on ActiveRecord::ActiveRecordError, wait: :polynomially_longer, attempts: 10

  public

  def perform(event_class_name, event_id)
    raise ArgumentError, "unsupported identity event class" unless EVENT_CLASSES.include?(event_class_name)

    event = event_class_name.constantize.find(event_id)
    OpIdentityEventInvalidator.call(event:)
  end
end
