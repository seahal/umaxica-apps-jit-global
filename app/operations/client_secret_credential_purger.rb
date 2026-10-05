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
          return :undelivered unless terminal_audits_complete?(credential, events)

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

    def terminal_audits_complete?(credential, events)
      return false if events.empty? || events.any? { |event| event.delivered_at.nil? }
      return false unless events.any? { |event|
        event.credential_ref == credential.public_id && event.event_name == "secret.discarded"
      }

      if credential.confirmed_at.nil? && events.none? { |event| event.reason == "withdrawal" }
        return false unless events.any? { |event| event.credential_ref.nil? }
      end

      events.all? { |event| durable_event?(event) }
    end

    def durable_event?(event)
      ChronicleRecord.connected_to(role: :writing) do
        recorded = Chronicle.find_by(event_uuid: event.event_id)
        metadata = {
          "client_ref" => event.client_ref,
          "credential_ref" => event.credential_ref,
          "actor_public_ref" => event.actor_public_ref,
          "item_count" => event.item_count,
        }.compact
        recorded && recorded.action == event.event_name && recorded.request_id == event.operation_ref &&
          recorded.metadata == metadata && recorded.occurred_at == event.occurred_at &&
          recorded.result == "succeeded" && recorded.reason == event.reason &&
          recorded.actor_type == event.actor_type && recorded.actor_id == event.actor_id &&
          recorded.subject_type == "Client" && recorded.subject_id == event.actor_id && recorded.changeset == {}
      end
    end

    def terminal_events(credential)
      if credential.confirmed_at || ClientSecretAuditOutbox.exists?(
        credential_ref: credential.public_id, event_name: "secret.discarded", reason: "withdrawal",
      )
        ClientSecretAuditOutbox.where(credential_ref: credential.public_id, event_name: "secret.discarded")
      else
        ClientSecretAuditOutbox.where(
          operation_ref: credential.issuance.origin_operation_id,
          credential_ref: [nil, credential.public_id], event_name: %w(secret.issuance_canceled secret.discarded),
        )
      end
    end
  end
end
