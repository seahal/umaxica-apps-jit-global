# frozen_string_literal: true

class ClientSecretIssuanceExpiryInvalidator
  class NotExpired < StandardError; end

  class InvalidState < StandardError; end

  class << self
    public

    def call!(issuance:, executor_job_id:, purge_after:)
      unless issuance.is_a?(ClientSecretIssuance) && issuance.persisted?
        raise ArgumentError, "Secret expiry requires a persisted app issuance"
      end
      unless executor_job_id.is_a?(String) && executor_job_id.valid_encoding? &&
          executor_job_id.present? && executor_job_id.length <= 255 && !executor_job_id.match?(/[[:cntrl:]]/)
        raise ArgumentError, "Secret expiry requires its job execution identifier"
      end
      unless purge_after.is_a?(ActiveSupport::Duration) && purge_after.value.finite? && purge_after.value.positive?
        raise ArgumentError, "Secret expiry requires an explicit positive finite retention duration"
      end

      AppZenithRecord.connected_to(role: :writing) do
        issuance.client.with_lock(requires_new: true) do
          owned = ClientSecretIssuance.lock.find_by!(
            id: issuance.id, public_id: issuance.public_id, client_id: issuance.client.id,
          )
          expire!(owned, executor_job_id, purge_after)
        end
      end
    end

    private

    def expire!(issuance, executor_job_id, duration)
      now = Client.database_now
      raise NotExpired, "only expired Secret allocations can be retired" unless issuance.state(at: now) == :expired

      ClientSecretCapacityQuery.call(client: issuance.client, at: now)
      candidates = ClientSecretCredential.where(issuance_id: issuance.id, client_id: issuance.client_id)
        .order(:id).lock.to_a
      finalized =
        candidates.any? do |candidate|
          candidate.confirmed_at || candidate.claimed_at || candidate.claim_operation_id || candidate.revoked_at
        end
      if candidates.length > issuance.planned_count || finalized
        raise InvalidState, "expired Secret issuance contains an inconsistent candidate set"
      end

      if issuance.discard_at != Float::INFINITY && issuance.discard_at <= now
        verify_retirement!(issuance, candidates, now)
        return issuance
      end

      purge_at = (now + duration).round(6)
      raise ArgumentError, "Secret expiry retention must advance the database timestamp" unless purge_at > now

      context = ActorValuesContext.empty
      ClientSecretAuditOutbox.record!(
        actor_context: context, client_ref: issuance.client.public_id, operation_ref: issuance.origin_operation_id,
        occurred_at: now, event_name: "secret.discarded", reason: "flow_expired",
        item_count: issuance.planned_count, executor_job_id: executor_job_id,
      )
      candidates.each do |candidate|
        candidate.update!(discard_at: now, purge_eligible_at: purge_at)
        ClientSecretAuditOutbox.record!(
          actor_context: context, client_ref: issuance.client.public_id, credential_ref: candidate.public_id,
          operation_ref: issuance.origin_operation_id, occurred_at: now,
          event_name: "secret.discarded", reason: "flow_expired", executor_job_id: executor_job_id,
        )
      end
      issuance.update!(encrypted_payload: nil, discard_at: now, purge_eligible_at: purge_at)
      issuance
    end

    def verify_retirement!(issuance, candidates, now)
      recorded = ClientSecretAuditOutbox.exists?(
        client_ref: issuance.client.public_id, credential_ref: nil, operation_ref: issuance.origin_operation_id,
        event_name: "secret.discarded", reason: "flow_expired", occurred_at: issuance.discard_at,
        actor_type: nil, actor_id: nil, actor_public_ref: nil, item_count: issuance.planned_count,
      )
      return if recorded && issuance.encrypted_payload.nil? && candidates.all? { |candidate| candidate.lapsed?(now) }

      raise InvalidState, "expired Secret retirement is missing its payload cleanup or source audit"

    end
  end
end
