# typed: false
# frozen_string_literal: true

class PasskeyAuditDeliveryJob < ApplicationJob
  queue_as :retention

  SOURCES = {
    ClientPasskeyAuditOutbox => "app",
    VisitorPasskeyAuditOutbox => "com",
    OperatorPasskeyAuditOutbox => "org",
  }.freeze

  public

  def perform(batch_size: 500)
    unless batch_size.is_a?(Integer) && batch_size.between?(1, 500)
      raise ArgumentError, "Passkey audit delivery requires a bounded batch"
    end

    failures = []
    SOURCES.each do |model, surface|
      failures.concat(deliver_source!(model, surface, batch_size))
    rescue StandardError => e
      failures << e
      Rails.error.report(
        e,
        handled: false,
        context: { job: self.class.name, source_model: model.name, surface:, batch_size: },
      )
    end

    raise failures.first if failures.any?
  end

  private

  def deliver_source!(model, surface, batch_size)
    failures = []
    model.connection_class_for_self.connected_to(role: :writing) do
      model.where(acknowledged_at: nil).order(:id).limit(batch_size).each do |event|
        begin
          event.with_lock do
            next if event.acknowledged_at

            audit = persist_chronicle!(event, surface)
            unless identity_matches?(audit, event, surface)
              raise ArgumentError, "Passkey Chronicle event identity conflicts with its source"
            end

            event.update!(acknowledged_at: model.database_now)
          end
        rescue StandardError => e
          failures << [event, e]
          Rails.error.report(
            e,
            handled: false,
            context: {
              job: self.class.name,
              source_model: model.name,
              surface:,
              event_uuid: event.event_uuid,
              batch_size:,
            },
          )
        end
      end
    end

    failures.map!(&:last)
  end

  def identity_matches?(audit, event, surface)
    audit.action == event.event_type &&
      audit.request_id == event.operation_ref &&
      audit.occurred_at == event.occurred_at &&
      audit.metadata == metadata_for(event, surface) &&
      audit.result == "succeeded" && audit.reason.nil? && audit.changeset == {}
  end

  def metadata_for(event, surface)
    {
      "surface" => surface,
      "external_id" => event.external_id.to_s,
      "actor_ref" => event.actor_ref,
      **(event.metadata || {}).stringify_keys,
    }.compact
  end

  def persist_chronicle!(event, surface)
    ChronicleRecord.connected_to(role: :writing) do
      prior = Chronicle.find_by(event_uuid: event.event_uuid)
      return prior if prior

      policy = ChronicleRecordPolicy.retention_policy_for(action: event.event_type)
      Chronicle.create!(
        event_uuid: event.event_uuid,
        action: event.event_type,
        result: "succeeded",
        occurred_at: event.occurred_at,
        request_id: event.operation_ref,
        metadata: metadata_for(event, surface),
        changeset: {},
        chronicle_retention_policy: policy,
        erasable_at: ChronicleRecordPolicy.erasable_at_for(policy: policy, occurred_at: event.occurred_at),
      )
    end
  rescue ActiveRecord::RecordNotUnique
    ChronicleRecord.connected_to(role: :writing) { Chronicle.find_by!(event_uuid: event.event_uuid) }
  end
end
