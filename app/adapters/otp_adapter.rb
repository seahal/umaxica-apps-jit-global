# typed: false
# frozen_string_literal: true

# Routes OTP delivery to the appropriate channel adapter based on surface and channel.
#
# Email delivery has one production path: the surface-specific Noticed adapter. Keeping
# that choice explicit here prevents a missing feature flag or unavailable flag store from
# silently returning to the retired direct-mailer path. See
# adr/notification-orchestration-via-noticed.md.
class OtpAdapter
  def self.for(surface:, channel:)
    case [surface.to_sym, channel.to_sym]
    when [:app, :email] then OtpEmailNotifierAdapter.new(Notify::App::OtpNotifier, surface: :app)
    when [:com, :email] then OtpEmailNotifierAdapter.new(Notify::Com::OtpNotifier, surface: :com)
    when [:org, :email] then OtpEmailNotifierAdapter.new(Notify::Org::OtpNotifier, surface: :org)
    when [:app, :telephone],
         [:com, :telephone],
         [:org, :telephone] then OtpTelephoneAdapter.new(surface: surface)
    else
      raise ArgumentError, "Unknown OTP delivery channel: #{surface}/#{channel}"
    end
  end

  def deliver(**)
    raise NotImplementedError, "#{self.class}#deliver is not implemented"
  end

  private

  def record_email_enqueue!(record:, purpose: nil)
    record_email_delivery_event!(
      event: "enqueued",
      record: record,
      purpose: purpose,
    )
  end

  def record_email_enqueue_failure!(record:, purpose:, error:)
    record_email_delivery_event!(
      event: "enqueue_failed",
      record: record,
      purpose: purpose,
      reason: error.class.name,
    )
  end

  def record_email_delivery_event!(event:, record:, purpose: nil, reason: nil)
    Chronicle.capture(
      action: "notification.delivery.email.#{event}",
      subject: record,
      metadata: { purpose: purpose.to_s.presence }.compact,
      reason: reason,
    )
  rescue StandardError => e
    Rails.logger.error(
      JitLogEvent.format(
        "notification.delivery_audit_failed",
        action: "notification.delivery.email.#{event}",
        error_class: e.class.name,
      ),
    )
    nil
  end
end
