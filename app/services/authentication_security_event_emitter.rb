# typed: false
# frozen_string_literal: true

# Emits authentication security events through both the durable Chronicle audit
# boundary and the repository log transport. The log line remains useful for
# operational correlation, but it is not the source of truth for the event.
class AuthenticationSecurityEventEmitter
  EVENTS = %w(
    sign_in.success
    sign_in.failure
    sign_up.success
    sign_up.failure
    sign_out.success
    passkey.used
    passkey.failed
    totp.failed
    recovery.used
    social.callback_failure
    entra.callback_failure
    ceremony.cleanup
    rate_limit.exceeded
    csrf.failure
    authorization.failure
    session.max_exceeded
    logout.forced
    policy.changed
  ).freeze

  def self.emit(event_type, actor: nil, subject: nil, request_id: nil, ip_address: nil, user_agent: nil,
                reason: nil, **payload)
    raise ArgumentError, "unknown authentication security event: #{event_type}" unless EVENTS.include?(event_type)

    severity = payload.delete(:severity) || payload.delete("severity") || "info"
    ip_address ||= payload.delete(:ip) || payload.delete("ip")
    safe_payload = ChronicleRecordPolicy.sanitize(payload.merge(severity: severity))

    Chronicle.capture(
      action: "authentication.security_event.#{event_type}",
      actor: actor,
      subject: subject,
      reason: reason,
      metadata: safe_payload,
      request_id: request_id,
      ip_address: ip_address,
      user_agent: user_agent,
    )

    Rails.logger.info(
      JitLogEvent.format(
        "authentication.security_event",
        event_type: event_type,
        severity: severity,
        **payload,
      ),
    )
  end
end
