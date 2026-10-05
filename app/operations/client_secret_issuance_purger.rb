# frozen_string_literal: true

# Collects retired, unconfirmed allocations only after their candidates and terminal audit.
class ClientSecretIssuancePurger
  class << self
    public

    def call!(issuance:, executor_job_id:)
      AppZenithRecord.connected_to(role: :writing) do
        issuance.client.with_lock do
          issuance.lock!
          now = Client.database_now
          return :pending unless issuance.confirmed_at.nil? && issuance.planned_count.positive? &&
            issuance.encrypted_payload.nil? && issuance.discard_at <= now && issuance.purge_eligible_at <= now
          return :dependent if ClientSecretCredential.exists?(issuance_id: issuance.id)
          return :held if issuance.client.client_retention_holds.active_at(now).exists? ||
            AppEnforcementCase.principal_effect_blocking?(issuance.client.public_id, :withdrawal_purge_blocked) ||
            AppEnforcementCase.principal_effect_blocking?(issuance.client.public_id, :principal_hard_delete_blocked)

          events = ClientSecretAuditOutbox.where(
            client_ref: issuance.client.public_id, operation_ref: issuance.origin_operation_id, credential_ref: nil,
            event_name: %w(secret.discarded secret.issuance_canceled), occurred_at: issuance.discard_at,
          ).lock.to_a
          return :undelivered if events.empty? || events.any? { |event| event.delivered_at.nil? }

          return :undelivered unless durable_events?(events)

          operation = issuance.origin_operation_id
          client_ref = issuance.client.public_id
          count = issuance.planned_count
          issuance.delete
          ClientSecretAuditOutbox.record!(
            actor_context: ActorValuesContext.empty, client_ref: client_ref, operation_ref: operation,
            occurred_at: now, event_name: "secret.issuance_purged", item_count: count,
            executor_job_id: executor_job_id,
          )
          :purged
        end
      end
    end

    private

    def durable_events?(events)
      ids = events.map(&:event_id)
      durable =
        ChronicleRecord.connected_to(role: :writing) do
          Chronicle.where(event_uuid: ids, result: "succeeded").pluck(:event_uuid)
        end
      durable.sort == ids.sort
    end
  end
end
