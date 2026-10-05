# frozen_string_literal: true

# Source delivery records are collectible only after their dependent facts retire.
class ClientSecretAuditOutboxPurger
  class << self
    public

    def call!(event:)
      unless event.is_a?(ClientSecretAuditOutbox) && event.persisted?
        raise ArgumentError, "Secret outbox collection requires a persisted source event"
      end

      AppZenithRecord.connected_to(role: :writing) do
        owner = Client.find_by(public_id: event.client_ref)
        if owner
          owner.with_lock { purge!(event, owner) }
        else
          # Client deletion does not cascade its independent source audit records.
          ClientSecretAuditOutbox.transaction { purge!(event, nil) }
        end
      end
    end

    private

    def purge!(event, owner)
      event.lock!
      now = Client.database_now
      return :undelivered unless event.delivered_at
      return :pending unless event.discard_at <= now && event.purge_eligible_at <= now
      return :replay_barrier if event.event_name == "secret.issuance_purged" && owner
      return :held if (owner && owner.client_retention_holds.active_at(now).exists?) ||
        AppEnforcementCase.principal_effect_blocking?(event.client_ref, :withdrawal_purge_blocked) ||
        AppEnforcementCase.principal_effect_blocking?(event.client_ref, :principal_hard_delete_blocked)
      return :dependent if dependent_facts?(event)

      return :undelivered unless durable_event?(event)

      event.delete
      :purged
    end

    def dependent_facts?(event)
      return true if event.credential_ref && ClientSecretCredential.exists?(public_id: event.credential_ref)
      return true if ClientSecretCredential.exists?(claim_operation_id: event.operation_ref)
      return true if ClientSecretIssuance.exists?(origin_operation_id: event.operation_ref)

      AppTicketRecord.connected_to(role: :writing) do
        ClientSecretSignInReceipt.exists?(operation_id: event.operation_ref)
      end
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
  end
end
