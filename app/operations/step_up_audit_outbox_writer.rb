# frozen_string_literal: true

class StepUpAuditOutboxWriter
  class << self
    public

    def call(**attributes)
      new(**attributes).call
    end
  end

  public

  def call
    model, pending_id = source_model
    validate_source_transaction!(model)
    validate_event!
    outbox = create_outbox!(model, pending_id)
    enqueue_after_commit
    outbox
  end

  private

  attr_reader :source_key, :event_type, :realm, :client_id, :subject_ref, :context_ref, :reason_code, :payload,
              :occurred_at

  def initialize(source_key:, event_type:, realm:, client_id:, subject_ref:, context_ref:, reason_code:, payload:,
                 occurred_at: nil)
    @source_key = source_key
    @event_type = event_type
    @realm = realm
    @client_id = client_id
    @subject_ref = subject_ref
    @context_ref = context_ref
    @reason_code = reason_code
    @payload = payload
    @occurred_at = occurred_at
  end

  def nonempty_bounded_string?(value, maximum:)
    value.is_a?(String) && value.present? && value.length <= maximum
  end

  def source_model
    model, expected_realm, _attempt_class, pending_id, _delivered_id =
      StepUpAuditOutboxSourcesRegistry::SOURCES.fetch(source_key) do
      raise ArgumentError, "unsupported step-up audit source: #{source_key.inspect}"
    end
    raise ArgumentError,
          "step-up audit realm does not match source #{source_key.inspect}" unless realm == expected_realm

    [model, pending_id]
  end

  def validate_source_transaction!(model)
    return if model.lease_connection.transaction_open?

    raise ArgumentError, "step-up audit outbox requires the source transaction"
  end

  def validate_event!
    raise ArgumentError, "unsupported step-up audit event type: #{event_type.inspect}" unless
      StepUpAuditCodesRegistry::EVENT_TYPES.include?(event_type)
    raise ArgumentError, "unsupported step-up audit reason code: #{reason_code.inspect}" unless
      StepUpAuditCodesRegistry::REASON_CODES.include?(reason_code)
    raise ArgumentError, "step-up audit payload does not match its event contract" unless
      StepUpAuditCodesRegistry.valid_payload?(event_type:, payload:)
    unless nonempty_bounded_string?(client_id, maximum: 64) &&
        nonempty_bounded_string?(subject_ref, maximum: 255) &&
        context_ref.is_a?(String) && context_ref.length == 21
      raise ArgumentError, "step-up audit references are invalid"
    end
    return if occurred_at.nil? || occurred_at.is_a?(Time)

    raise ArgumentError, "step-up audit occurrence time must be a Time"
  end

  def create_outbox!(model, pending_id)
    model.create!(
      event_uuid: SecureRandom.uuid,
      event_type:,
      realm:,
      client_id:,
      subject_ref:,
      context_ref:,
      reason_code:,
      payload: payload.deep_stringify_keys,
      occurred_at: occurred_at || model.database_now,
      delivery_state_id: pending_id,
    )
  end

  def enqueue_after_commit
    # The source outbox remains authoritative if the queue is unavailable; the recurring sweep retries it.
    ActiveRecord.after_all_transactions_commit do
      begin
        enqueued = StepUpAuditDeliveryJob.perform_later(source_key: source_key)
        next unless enqueued == false

        Rails.logger.warn(
          JitLogEvent.format("step_up.audit_delivery.enqueue", source_key: source_key, outcome: "unavailable"),
        )
      rescue StandardError => e
        Rails.error.report(e, handled: true, context: { source_key: source_key })
      end
    end
  end
end
