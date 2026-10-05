# frozen_string_literal: true

# Scanning, rather than enqueue success, is the delivery authority.
class ClientSecretAuditDeliveryJob < ApplicationJob
  queue_as :retention

  public

  def perform(batch_size: 500, retention_seconds:)
    unless batch_size.is_a?(Integer) && batch_size.between?(1, 500) &&
        retention_seconds.is_a?(Integer) && retention_seconds.positive?
      raise ArgumentError, "Secret audit delivery requires bounded batching and finite retention"
    end

    AppZenithRecord.connected_to(role: :writing) do
      ClientSecretAuditOutbox.where(delivered_at: nil).order(:id).limit(batch_size).each do |event|
        event.with_lock do
          next if event.delivered_at

          chronicle = persist_chronicle!(event)
          unless chronicle.action == event.event_name && chronicle.request_id == event.operation_ref &&
              chronicle.metadata == metadata_for(event) && chronicle.occurred_at == event.occurred_at &&
              chronicle.result == "succeeded" && chronicle.reason == event.reason &&
              chronicle.actor_type == event.actor_type && chronicle.actor_id == event.actor_id &&
              chronicle.subject_type == "Client" && chronicle.subject_id == event.actor_id && chronicle.changeset == {}
            raise ArgumentError, "Secret Chronicle event identity conflicts with its source"
          end

          now = ClientSecretAuditOutbox.database_now
          event.update!(delivered_at: now, discard_at: now, purge_eligible_at: now + retention_seconds.seconds)
        end
      end
    end
  end

  private

  def metadata_for(event)
    { "client_ref" => event.client_ref,
      "credential_ref" => event.credential_ref,
      "actor_public_ref" => event.actor_public_ref,
      "item_count" => event.item_count, }.compact
  end

  def persist_chronicle!(event)
    ChronicleRecord.connected_to(role: :writing) do
      prior = Chronicle.find_by(event_uuid: event.event_id)
      return prior if prior

      # Reuse the accepted security retention policy; missing policy is an operational error.
      policy = ChronicleRetentionPolicy.find_by!(code: "security")
      Chronicle.create!(
        event_uuid: event.event_id, action: event.event_name, result: "succeeded", reason: event.reason,
        actor_type: event.actor_type, actor_id: event.actor_id, subject_type: "Client",
        chronicle_retention_policy: policy, subject_id: event.actor_id, occurred_at: event.occurred_at,
        erasable_at: ChronicleRecordPolicy.erasable_at_for(policy: policy, occurred_at: event.occurred_at),
        request_id: event.operation_ref, metadata: metadata_for(event), changeset: {},
      )
    end
  rescue ActiveRecord::RecordNotUnique
    ChronicleRecord.connected_to(role: :writing) { Chronicle.find_by!(event_uuid: event.event_id) }
  end
end
