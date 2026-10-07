# frozen_string_literal: true

# Periodic Source scans are authoritative, independently of enqueue success.
class ContactAuditDeliveryJob < ApplicationJob
  queue_as :retention

  public

  def perform(batch_size: 500)
    unless batch_size.is_a?(Integer) && batch_size.between?(1, 500)
      raise ArgumentError, "Contact audit delivery requires a bounded batch"
    end

    deliver_source!(ClientContactAuditOutbox, "app", batch_size)
    deliver_source!(VisitorContactAuditOutbox, "com", batch_size)
  end

  private

  def deliver_source!(model, surface, batch_size)
    model.connection_class_for_self.connected_to(role: :writing) do
      model.where(acknowledged_at: nil).order(:id).limit(batch_size).each do |event|
        event.with_lock do
          next if event.acknowledged_at

          audit = persist_chronicle!(event, surface)
          unless identity_matches?(audit, event, surface)
            raise ArgumentError, "Contact Chronicle event identity conflicts with its Source"
          end

          event.update!(acknowledged_at: model.database_now)
        end
      end
    end
  end

  def identity_matches?(audit, event, surface)
    audit.action == "contact.#{event.contact_kind}.#{event.event_name}" &&
      audit.request_id == event.operation_ref && audit.occurred_at == event.occurred_at &&
      audit.metadata == metadata_for(event, surface) && audit.result == "succeeded" &&
      audit.reason.nil? && audit.actor_type.nil? && audit.actor_id.nil? &&
      audit.subject_type.nil? && audit.subject_id.nil? && audit.changeset == {}
  end

  def metadata_for(event, surface)
    { "surface" => surface,
      "owner_ref" => event.owner_ref,
      "contact_ref" => event.contact_ref,
      "actor_ref" => event.actor_ref, }.compact
  end

  def persist_chronicle!(event, surface)
    ChronicleRecord.connected_to(role: :writing) do
      prior = Chronicle.find_by(event_uuid: event.event_uuid)
      return prior if prior

      policy = ChronicleRetentionPolicy.find_by!(code: "security")
      Chronicle.create!(
        event_uuid: event.event_uuid, action: "contact.#{event.contact_kind}.#{event.event_name}",
        result: "succeeded", occurred_at: event.occurred_at, request_id: event.operation_ref,
        metadata: metadata_for(event, surface), changeset: {}, chronicle_retention_policy: policy,
        erasable_at: ChronicleRecordPolicy.erasable_at_for(policy: policy, occurred_at: event.occurred_at),
      )
    end
  rescue ActiveRecord::RecordNotUnique
    ChronicleRecord.connected_to(role: :writing) { Chronicle.find_by!(event_uuid: event.event_uuid) }
  end
end
