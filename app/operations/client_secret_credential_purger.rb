# frozen_string_literal: true

# Sole app Secret DELETE owner. The accepted rebuild ADR requires prior terminal
# Chronicle commit and an atomic surviving purged outbox record.
class ClientSecretCredentialPurger
  class << self
    public

    def call!(credential:, executor_job_id:)
      AppZenithRecord.connected_to(role: :writing) do
        credential.client.with_lock do
          credential.lock!
          now = Client.database_now
          return :pending unless credential.lapsed?(now) && credential.purgeable?(now)
          return :held if credential.client.client_retention_holds.active_at(now).exists? ||
            AppEnforcementCase.principal_effect_blocking?(credential.client.public_id, :withdrawal_purge_blocked) ||
            AppEnforcementCase.principal_effect_blocking?(credential.client.public_id, :principal_hard_delete_blocked)

          events = terminal_events(credential).lock.to_a
          return :undelivered if events.empty? || events.any? { |event| event.delivered_at.nil? }

          event_ids = events.map(&:event_id)
          durable_ids =
            ChronicleRecord.connected_to(role: :writing) do
              Chronicle.where(event_uuid: event_ids, result: "succeeded").pluck(:event_uuid)
            end
          return :undelivered unless durable_ids.sort! == event_ids.sort!

          reference = credential.public_id
          client_ref = credential.client.public_id
          operation = credential.claim_operation_id || credential.issuance.origin_operation_id
          credential.delete
          ClientSecretAuditOutbox.record!(
            actor_context: ActorValuesContext.empty, client_ref: client_ref, credential_ref: reference,
            operation_ref: operation, occurred_at: now, event_name: "secret.purged",
            executor_job_id: executor_job_id, item_count: 1,
          )
          :purged
        end
      end
    end

    private

    def terminal_events(credential)
      if credential.confirmed_at || ClientSecretAuditOutbox.exists?(
        credential_ref: credential.public_id, event_name: "secret.discarded", reason: "withdrawal",
      )
        ClientSecretAuditOutbox.where(credential_ref: credential.public_id, event_name: "secret.discarded")
      else
        ClientSecretAuditOutbox.where(
          operation_ref: credential.issuance.origin_operation_id,
          credential_ref: nil, event_name: %w(secret.issuance_canceled secret.discarded),
        )
      end
    end
  end
end
