# typed: false
# frozen_string_literal: true

# Records that the system halted a sign flow, with the reason code the lifecycle ADR requires.
#
# The durable record is a Chronicle event on the flow's principal, which the caller resolves before
# terminating the flow. A flow that has no principal yet has no audit subject, so only the
# structured log line is written for it; the terminal flow row remains the fact of the halt until
# its retention lapses.
#
# The context carries correlation only: never the flow binding, the locator nonce, a code, a
# credential id, or a contact address.
class SignFlowHaltRecorder
  REASON_CODES = %w(phase_regression phase_violation superseded_by_restart).freeze
  LOG_EVENT = "sign.flow.halted"

  private_constant :LOG_EVENT

  def self.call(flow:, subject:, surface:, flow_kind:, reason_code:, request_id: nil, expected_phase: nil,
                requested_phase: nil)
    new(flow, subject, surface, flow_kind, reason_code, request_id, expected_phase, requested_phase).call
  end
  public_class_method :call

  public

  def initialize(flow, subject, surface, flow_kind, reason_code, request_id, expected_phase, requested_phase)
    unless REASON_CODES.include?(reason_code.to_s)
      raise ArgumentError, "unsupported sign flow halt reason: #{reason_code.inspect}"
    end

    @subject = subject
    @context = {
      flow_kind: flow_kind.to_s,
      flow_public_id: flow.public_id,
      surface: surface.to_s,
      reason_code: reason_code.to_s,
      request_id: request_id,
      expected_phase: expected_phase&.to_s,
      requested_phase: requested_phase&.to_s,
      halted_at: Time.current.iso8601,
    }.compact
  end

  def call
    Rails.logger.warn(JitLogEvent.format(LOG_EVENT, **@context))

    return false unless @subject

    AuthenticationAuditWriter.write(audit_class, audit_event_id, resource: @subject, actor: @subject, context: @context)
  end

  private

  # Visitors are recorded in the client chronicle, as every other visitor authentication event is.
  def audit_class
    case @subject
    when Client, Visitor then ClientChronicle
    when Operator then OperatorChronicle
    else raise ArgumentError, "unsupported sign flow audit subject: #{@subject.class.name}"
    end
  end

  def audit_event_id
    case @subject
    when Client, Visitor then ClientChronicleEvent::SIGN_FLOW_HALTED
    when Operator then OperatorChronicleEvent::SIGN_FLOW_HALTED
    else raise ArgumentError, "unsupported sign flow audit subject: #{@subject.class.name}"
    end
  end
end
