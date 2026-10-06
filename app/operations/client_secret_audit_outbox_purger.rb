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
          owner.with_lock do
            if event.event_name == "secret.issuance_purged"
              with_ticket_replay_barrier_lock { purge!(event, owner) }
            else
              purge!(event, owner)
            end
          end
        else
          # Client deletion does not cascade its independent source audit records.
          if event.event_name == "secret.issuance_purged"
            with_ticket_replay_barrier_lock { ClientSecretAuditOutbox.transaction { purge!(event, nil) } }
          else
            ClientSecretAuditOutbox.transaction { purge!(event, nil) }
          end
        end
      end
    end

    private

    def purge!(event, owner)
      event.lock!
      now = Client.database_now
      return :undelivered unless event.delivered_at
      return :pending unless event.discard_at <= now && event.purge_eligible_at <= now

      if event.event_name == "secret.issuance_purged"
        return :replay_barrier unless replay_barrier_retirable?(event, owner, now)
      end
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

    def with_ticket_replay_barrier_lock
      AppTicketRecord.connected_to(role: :writing) do
        AppTicketRecord.transaction(requires_new: true) { yield }
      end
    end

    def replay_barrier_retirable?(event, owner, now)
      return false unless owner
      return false unless event.issuance_origin.present? &&
        ((event.issuance_browser_session_ref.present?) ^ (event.issuance_sign_up_flow_ref.present?))

      authority =
        if event.issuance_browser_session_ref.present?
          ClientToken.lock.find_by(public_id: event.issuance_browser_session_ref, user_id: owner.id)
        else
          ClientSignUpFlow.lock.find_by(public_id: event.issuance_sign_up_flow_ref, principal_id: owner.id)
        end
      return false unless authority

      authority_deadline = authority_terminal_at(authority, now)
      return false unless authority_deadline

      [event.purge_eligible_at, authority_deadline + ClientSecretLifetimesValue.proof_retention].max <= now
    end

    def authority_terminal_at(authority, now)
      case authority
      when ClientToken
        return nil if authority.currently_usable?(now)

        timestamp = authority.discard_at
        return timestamp if timestamp.is_a?(Time) || timestamp.is_a?(ActiveSupport::TimeWithZone)

        authority.updated_at
      when ClientSignUpFlow
        terminal_statuses = %w(COMPLETED FAILED EXPIRED CANCELLED HALTED FINALIZED SIGN_IN_HANDOFF_PENDING)
        return nil unless terminal_statuses.include?(ClientSignUpFlow::STATUS_NAMES.fetch(authority.status_id)) || authority.expired?(now)

        [authority.expires_at, authority.updated_at].compact.max
      else
        nil
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
