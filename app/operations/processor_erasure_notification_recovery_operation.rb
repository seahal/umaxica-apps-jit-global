# frozen_string_literal: true

class ProcessorErasureNotificationRecoveryOperation
  class Unauthorized < StandardError; end

  class << self
    public

    def call(notification:, authorized_by:)
      new(notification:, authorized_by:).call
    end
  end

  def initialize(notification:, authorized_by:)
    @notification = notification
    @authorized_by = authorized_by
  end

  public

  def call
    unless ProcessorErasureNotificationRecoveryPolicy.new(notification, user: authorized_by).recover?
      raise Unauthorized, "processor notification recovery is not authorized"
    end

    old_generation = notification.delivery_generation
    record_recovery_request!(old_generation: old_generation)
    notification.start_new_delivery_generation!
  end

  private

  attr_reader :notification, :authorized_by

  def record_recovery_request!(old_generation:)
    WithdrawalOccurrenceRecording.record!(
      subject: subject_for(notification),
      actor: authorized_by,
      event_type: "processor_erasure.manual_recovery_requested",
      context: {
        processor_key: notification.processor_key,
        processor_notification_public_id: notification.public_id,
        privacy_request_public_id: privacy_request_for(notification).public_id,
        delivery_generation: old_generation,
        reason_code: "authorized_manual_recovery",
      },
    )
  end

  def subject_for(record)
    case record
    when ClientProcessorErasureNotification then record.client_privacy_request.client
    when VisitorProcessorErasureNotification then record.visitor_privacy_request.visitor
    else raise ArgumentError, "unsupported processor notification: #{record.class.name}"
    end
  end

  def privacy_request_for(record)
    case record
    when ClientProcessorErasureNotification then record.client_privacy_request
    when VisitorProcessorErasureNotification then record.visitor_privacy_request
    else raise ArgumentError, "unsupported processor notification: #{record.class.name}"
    end
  end
end
