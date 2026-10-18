# typed: false
# frozen_string_literal: true

class ProcessorErasureNotificationRetryJob < ApplicationJob
  queue_as :retention

  DEFAULT_BATCH_SIZE = 100
  MAX_BATCH_SIZE = 500

  public

  def perform(batch_size: DEFAULT_BATCH_SIZE)
    limit = normalized_batch_size(batch_size)
    unless limit&.between?(1, MAX_BATCH_SIZE)
      raise ArgumentError, "batch_size must be between 1 and #{MAX_BATCH_SIZE}"
    end

    enqueue_due(ClientProcessorErasureNotification, "app", limit)
    enqueue_due(VisitorProcessorErasureNotification, "com", limit)
  end

  private

  def normalized_batch_size(value)
    return value if value.is_a?(Integer)
    return Integer(value) if value.is_a?(String)

    nil
  rescue ArgumentError, TypeError
    nil
  end

  def enqueue_due(notification_class, surface, batch_size)
    now = notification_class.database_now
    notification_class.pending_for_processing(now).order(:id).limit(batch_size).pluck(:public_id).each do |public_id|
      ProcessorErasureNotificationJob.perform_later(surface: surface, public_id: public_id)
    end
  end
end
