# frozen_string_literal: true

class StepUpAuditDeliveryJob < ApplicationJob
  queue_as :retention

  RESULTS_BY_EVENT = {
    "step_up.requested" => "intent",
    "step_up.committed" => "succeeded",
    "step_up.installed" => "succeeded",
    "step_up.cancelled" => "failed",
    "step_up.expired" => "failed",
    "step_up.failed" => "failed",
    "step_up.refused" => "failed",
    "step_up.indeterminate" => "failed",
    "step_up.attempt_rejected" => "failed",
  }.freeze

  public

  def perform(batch_size: 500, source_key: nil)
    unless batch_size.is_a?(Integer) && batch_size.between?(1, 500)
      raise ArgumentError, "Step-up audit delivery requires a bounded batch"
    end

    sources =
      if source_key
        { source_key => StepUpAuditOutboxSourcesRegistry::SOURCES.fetch(source_key) do
          raise ArgumentError, "unsupported step-up audit source: #{source_key.inspect}"
        end }
      else
        StepUpAuditOutboxSourcesRegistry::SOURCES
      end

    failures = []
    sources.each do |key, (model, realm, attempt_class, pending_id, delivered_id)|
      failures.concat(deliver_source!(key, model, realm, attempt_class, pending_id, delivered_id, batch_size))
    rescue StandardError => e
      failures << e
      report_failure(e, source_key: key, batch_size:)
    end

    raise failures.first if failures.any?
  end

  private

  def deliver_source!(source_key, model, realm, attempt_class, pending_id, delivered_id, batch_size)
    failures = []
    model.connection_class_for_self.connected_to(role: :writing) do
      upper_id = model.where(delivery_state_id: pending_id).maximum(:id)
      next unless upper_id

      cursor = nil
      loop do
        scope = model.where(delivery_state_id: pending_id, id: ..upper_id).order(:id)
        scope = scope.where("id > ?", cursor) if cursor
        events = scope.limit(batch_size).to_a
        break if events.empty?

        events.each do |event|
          error = deliver_event!(event, model, attempt_class, pending_id, delivered_id, realm)
          next unless error

          failures << error
          report_failure(error, source_key:, event_uuid: event.event_uuid, batch_size:)
        end
        cursor = events.last.id
      end
    end
    failures
  end

  def deliver_event!(event, model, attempt_class, pending_id, delivered_id, expected_realm)
    failure = nil

    event.with_lock do
      next unless event.delivery_state_id == pending_id

      begin
        validate_source_event!(event, expected_realm)
        chronicle, retention_policy = persist_chronicle!(event)
        unless identity_matches?(chronicle, event, retention_policy)
          raise StepUpAuditIdentityConflictError, "step-up Chronicle event identity conflicts with its source"
        end
      rescue StandardError => e
        failure = e
        attempt_class.create!(
          outbox: event,
          attempt_number: next_attempt_number(attempt_class, event),
          attempted_at: model.database_now,
          outcome: "failed",
          failure_code: failure_code_for(e),
        )
        next
      end

      attempt_class.create!(
        outbox: event,
        attempt_number: next_attempt_number(attempt_class, event),
        attempted_at: model.database_now,
        outcome: "delivered",
        failure_code: "none",
      )
      event.update!(delivery_state_id: delivered_id)
    end

    failure
  end

  def next_attempt_number(attempt_class, event)
    attempt_class.where(outbox_id: event.id).maximum(:attempt_number).to_i + 1
  end

  def persist_chronicle!(event)
    ChronicleRecord.connected_to(role: :writing) do
      policy = ChronicleRecordPolicy.retention_policy_for(action: event.event_type)
      prior = Chronicle.find_by(event_uuid: event.event_uuid)
      return [prior, policy] if prior

      chronicle = Chronicle.create!(
        event_uuid: event.event_uuid,
        action: event.event_type,
        result: result_for(event),
        reason: event.reason_code,
        occurred_at: event.occurred_at,
        metadata: metadata_for(event),
        changeset: {},
        chronicle_retention_policy: policy,
        erasable_at: ChronicleRecordPolicy.erasable_at_for(policy:, occurred_at: event.occurred_at),
      )
      [chronicle, policy]
    end
  rescue ActiveRecord::RecordNotUnique
    ChronicleRecord.connected_to(role: :writing) do
      policy = ChronicleRecordPolicy.retention_policy_for(action: event.event_type)
      [Chronicle.find_by!(event_uuid: event.event_uuid), policy]
    end
  end

  def validate_source_event!(event, expected_realm)
    valid_references = event.client_id.is_a?(String) && event.client_id.present? && event.client_id.length <= 64 &&
      event.subject_ref.is_a?(String) && event.subject_ref.present? && event.subject_ref.length <= 255 &&
      event.context_ref.is_a?(String) && event.context_ref.length == 21
    valid_codes = StepUpAuditCodesRegistry::EVENT_TYPES.include?(event.event_type) &&
      StepUpAuditCodesRegistry::REASON_CODES.include?(event.reason_code)

    return if event.realm == expected_realm && valid_references && valid_codes &&
      StepUpAuditCodesRegistry.valid_payload?(event_type: event.event_type, payload: event.payload)

    raise ArgumentError, "step-up audit source event does not match its contract"
  end

  def metadata_for(event)
    ChronicleRecordPolicy.sanitize(
      {
        "realm" => event.realm,
        "client_id" => event.client_id,
        "subject_ref" => event.subject_ref,
        "context_ref" => event.context_ref,
        "reason_code" => event.reason_code,
        "payload" => event.payload.deep_stringify_keys,
      },
    ).deep_stringify_keys
  end

  def result_for(event)
    return RESULTS_BY_EVENT.fetch(event.event_type) unless event.event_type == "sensitive_admission.closed"

    { "completed" => "succeeded", "expired" => "failed", "user_cancelled" => "failed" }.fetch(event.reason_code)
  end

  def identity_matches?(chronicle, event, retention_policy)
    expected_erasable_at = ChronicleRecordPolicy.erasable_at_for(
      policy: retention_policy,
      occurred_at: event.occurred_at,
    )

    chronicle.event_uuid == event.event_uuid &&
      chronicle.action == event.event_type &&
      chronicle.result == result_for(event) &&
      chronicle.reason == event.reason_code &&
      chronicle.occurred_at == event.occurred_at &&
      chronicle.request_id.nil? &&
      chronicle.metadata == metadata_for(event) &&
      chronicle.changeset == {} &&
      chronicle.chronicle_retention_policy_id == retention_policy.id &&
      chronicle.erasable_at == expected_erasable_at &&
      chronicle.actor_type.nil? && chronicle.actor_id.nil? &&
      chronicle.subject_type.nil? && chronicle.subject_id.nil? &&
      chronicle.ip_address.nil? && chronicle.user_agent.nil?
  end

  def failure_code_for(error)
    return "event_identity_conflict" if error.is_a?(StepUpAuditIdentityConflictError)
    return "retention_policy_missing" if error.is_a?(ActiveRecord::RecordNotFound)
    return "chronicle_unavailable" if chronicle_connection_failure?(error)
    return "chronicle_record_invalid" if error.is_a?(ActiveRecord::RecordInvalid)
    return "chronicle_record_invalid" if error.is_a?(ActiveRecord::StatementInvalid)

    "delivery_failed"
  end

  def chronicle_connection_failure?(error)
    return true if error.is_a?(ActiveRecord::ConnectionNotEstablished)
    return true if error.class.name == "ActiveRecord::ConnectionTimeoutError"

    cause_name = error.cause&.class&.name
    %w(PG::ConnectionBad PG::UnableToSend).include?(cause_name)
  end

  def report_failure(error, source_key:, batch_size:, event_uuid: nil)
    Rails.error.report(
      error,
      handled: false,
      context: {
        job: self.class.name,
        source_key:,
        event_uuid:,
        failure_code: failure_code_for(error),
        batch_size:,
      },
    )
  end
end
