# typed: false
# frozen_string_literal: true

# adr/operator-capability-authorization.md, Audit. Wraps one org administrative mutation in the
# existing Chronicle intent/result records (ChronicleIntentWriter, ChronicleResultWriter,
# ChronicleInvalidator) so that:
#
# - the mutation does not start unless its durable intent row is written;
# - the intent row's `event_uuid` is the client-submitted operation id, so a resubmission of the
#   same operation returns the recorded one instead of executing again, and a resubmission with
#   different content is rejected;
# - a failed result write leaves the row in `intent` or `manual_recovery_required`, which the
#   result page and the Chronicle recovery procedure both read. It is never reported as complete.
#
# Chronicle is a separate database from every surface's zenith database, so the intent, the
# mutation, and the result are three commits, not one transaction.
#
# Contract with the including controller: it provides `current_operator` and the Rails `request`.
# Authorization and Step-Up are declared by the including controller before this runs; nothing here
# authorizes.
module OrgAdministrativeAudit
  extend ActiveSupport::Concern

  OPERATION_ID_FORMAT = /\A\h{8}-\h{4}-4\h{3}-[89ab]\h{3}-\h{12}\z/

  class IntentUnavailableError < StandardError; end

  class OperationConflictError < StandardError; end

  class InvalidOperationIdError < StandardError; end

  private

  # Yields only when this operation id has not been recorded before. The block performs the
  # mutation and returns a small changeset describing what it observed. Returns the Chronicle row.
  def audited_administrative_operation(operation_id:, action:, subject:, reason_code:, metadata:, changeset:)
    raise InvalidOperationIdError unless operation_id.is_a?(String) && OPERATION_ID_FORMAT.match?(operation_id)

    recorded = recorded_administrative_operation(operation_id, action:, subject:, reason_code:)
    return recorded if recorded

    chronicle = write_administrative_intent!(operation_id, action:, subject:, reason_code:, metadata:, changeset:)
    return recorded_administrative_operation(operation_id, action:, subject:, reason_code:) if chronicle.nil?

    begin
      observed = yield
    rescue StandardError => e
      finish_administrative_operation(chronicle, "failed", action:, subject:, changeset: { error_class: e.class.name })
      raise
    end

    finish_administrative_operation(chronicle, "succeeded", action:, subject:, changeset: observed)
  end

  def recorded_administrative_operation(operation_id, action:, subject:, reason_code:)
    chronicle = Chronicle.find_by(event_uuid: operation_id)
    return nil if chronicle.nil?

    same = chronicle.action == action && chronicle.reason == reason_code &&
      chronicle.actor_type == current_operator.class.name && chronicle.actor_id == current_operator.id &&
      chronicle.subject_type == subject.class.name && chronicle.subject_id == subject.id
    raise OperationConflictError unless same

    chronicle
  end

  # Returns nil when a concurrent request already recorded the same operation id.
  def write_administrative_intent!(operation_id, action:, subject:, reason_code:, metadata:, changeset:)
    ChronicleIntentWriter.call(
      event_uuid: operation_id,
      action: action,
      actor: current_operator,
      subject: subject,
      reason: reason_code,
      metadata: metadata,
      changeset: changeset,
      request_id: request.request_id,
      ip_address: request.remote_ip,
      user_agent: request.user_agent,
    )
  rescue ActiveRecord::RecordNotUnique
    nil
  rescue ActiveRecord::RecordInvalid => e
    return nil if e.record.errors.of_kind?(:event_uuid, :taken)

    raise IntentUnavailableError, e.class.name
  rescue StandardError => e
    ChronicleFallbackRecorder.call(
      event: "chronicle.intent_write_failed",
      event_uuid: operation_id,
      request_id: request.request_id,
      action: action,
      actor: current_operator,
      subject: subject,
      error: e,
    )
    raise IntentUnavailableError, e.class.name
  end

  def finish_administrative_operation(chronicle, result, action:, subject:, changeset:)
    ChronicleResultWriter.call(
      chronicle: chronicle,
      result: result,
      event_uuid: chronicle.event_uuid,
      request_id: request.request_id,
      action: action,
      actor: current_operator,
      subject: subject,
      changeset: changeset,
    )
  rescue StandardError => e
    begin
      ChronicleInvalidator.call(
        chronicle: chronicle,
        event_uuid: chronicle.event_uuid,
        request_id: request.request_id,
        action: action,
        actor: current_operator,
        subject: subject,
        error: e,
      )
    rescue StandardError => invalidation_error
      ChronicleFallbackRecorder.call(
        event: "chronicle.manual_recovery_required",
        event_uuid: chronicle.event_uuid,
        request_id: request.request_id,
        action: action,
        actor: current_operator,
        subject: subject,
        error: invalidation_error,
        manual_recovery_required: true,
      )
    end
    chronicle
  end
end
