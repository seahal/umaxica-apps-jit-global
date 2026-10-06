# frozen_string_literal: true

# Collects retired allocations only after their dependencies and durable terminal audit.
class ClientSecretIssuancePurger
  class << self
    public

    def call_omitted!(issuance:, executor_job_id:, retention_after:)
      collect_bound!(issuance, executor_job_id, retention_after, :omitted)
    end

    def call_confirmed!(issuance:, executor_job_id:, retention_after:)
      collect_bound!(issuance, executor_job_id, retention_after, :confirmed)
    end

    def call_terminated_signup!(issuance:, executor_job_id:, retention_after:)
      collect_bound!(issuance, executor_job_id, retention_after, :terminated_signup)
    end

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

          delete_with_audit!(issuance, executor_job_id, now)
        end
      end
    end

    private

    def collect_bound!(issuance, executor_job_id, retention_after, expected_state)
      unless issuance.is_a?(ClientSecretIssuance) && issuance.persisted? &&
          retention_after.is_a?(ActiveSupport::Duration) && retention_after.value.finite? &&
          retention_after.value.positive?
        raise ArgumentError, "Completed Secret collection requires a persisted allocation and explicit finite retention"
      end

      AppZenithRecord.connected_to(role: :writing) do
        issuance.client.with_lock do
          AppTicketRecord.connected_to(role: :writing) do
            ClientToken.transaction do
              binding = omitted_binding(issuance)
              if expected_state != :terminated_signup && binding.is_a?(ClientSignUpFlow) && !binding.sign_up_completed?
                return :dependent
              end

              deadline = omitted_binding_deadline(binding)
              return :dependent if deadline == Float::INFINITY
              if binding && !deadline.is_a?(Time) && !deadline.is_a?(ActiveSupport::TimeWithZone)
                raise ArgumentError, "Omitted allocation binding requires a finite expiry"
              end

              case expected_state
              when :omitted
                purge_omitted!(issuance, executor_job_id, retention_after, deadline)
              when :confirmed
                purge_confirmed!(issuance, executor_job_id, retention_after, deadline)
              when :terminated_signup
                purge_terminated_signup!(issuance, executor_job_id, retention_after, binding)
              else
                raise ArgumentError, "Unsupported completed allocation state"
              end
            end
          end
        end
      end
    end

    def omitted_binding_deadline(binding)
      case binding
      when ClientSignUpFlow
        binding.expires_at
      when ClientToken
        binding.discard_at
      when nil
        nil
      else
        raise ArgumentError, "Omitted allocation has an unsupported authority binding"
      end
    end

    def purge_terminated_signup!(issuance, executor_job_id, duration, flow)
      return :dependent unless flow.is_a?(ClientSignUpFlow) &&
        %w(CANCELLED EXPIRED FAILED HALTED FINALIZED SIGN_IN_HANDOFF_PENDING).include?(
          ClientSignUpFlow::STATUS_NAMES.fetch(flow.status_id),
        )

      issuance.lock!
      now = Client.database_now
      return :dependent if issuance.signup_completed_at || ClientSecretCredential.exists?(issuance_id: issuance.id)
      return :pending unless retired_signup_deadline?(issuance, flow, duration, now)
      return :held if issuance_held?(issuance, now)

      events = terminated_signup_audit_events(issuance, flow)
      return :undelivered if events.empty? || events.any? { |event| event.delivered_at.nil? }

      refs = events.filter_map(&:credential_ref)
      return :dependent if ClientSecretSignInReceipt.exists?(credential_ref: refs)
      return :undelivered unless durable_events?(events) && durable_credential_purges?(issuance, refs)

      delete_with_audit!(issuance, executor_job_id, now)
    end

    def terminated_signup_audit_events(issuance, flow)
      reason = {
        "CANCELLED" => "flow_canceled",
        "EXPIRED" => "flow_expired",
        "FAILED" => "flow_failed",
        "HALTED" => "flow_halted",
        "FINALIZED" => "flow_halted",
        "SIGN_IN_HANDOFF_PENDING" => "flow_halted",
      }
        .fetch(ClientSignUpFlow::STATUS_NAMES.fetch(flow.status_id))
      reasons = [reason]
      if issuance.confirmed_at.nil? && issuance.expires_at && issuance.expires_at <= issuance.discard_at
        reasons << "flow_expired"
      end
      if issuance.confirmed_at.nil? && issuance.canceled_at == issuance.discard_at
        reasons << "payload_unavailable"
      end
      events = ClientSecretAuditOutbox.where(
        client_ref: issuance.client.public_id, operation_ref: issuance.origin_operation_id,
        event_name: %w(secret.discarded secret.issuance_canceled), reason: reasons, occurred_at: issuance.discard_at,
      ).lock.to_a
      allocation_events = events.select { |event| event.credential_ref.nil? }
      return [] unless allocation_events.one? && allocation_events.first.item_count == issuance.planned_count

      refs = events.filter_map(&:credential_ref)
      return [] if refs.uniq.size != refs.size || refs.size > issuance.planned_count

      events
    end

    def issuance_held?(issuance, now)
      issuance.client.client_retention_holds.active_at(now).exists? ||
        AppEnforcementCase.principal_effect_blocking?(issuance.client.public_id, :withdrawal_purge_blocked) ||
        AppEnforcementCase.principal_effect_blocking?(issuance.client.public_id, :principal_hard_delete_blocked)
    end

    def retired_signup_deadline?(issuance, flow, duration, now)
      return false if issuance.discard_at == Float::INFINITY || issuance.purge_eligible_at == Float::INFINITY

      issuance.encrypted_payload.nil? && issuance.discard_at <= now && issuance.purge_eligible_at <= now &&
        [flow.expires_at, issuance.purge_eligible_at].max + duration <= now
    end

    def purge_confirmed!(issuance, executor_job_id, retention_after, binding_deadline)
      issuance.lock!
      now = Client.database_now
      return :pending unless issuance.state(at: now) == :confirmed && issuance.encrypted_payload.nil?
      return :dependent if ClientSecretCredential.exists?(issuance_id: issuance.id) ||
        (issuance.sign_up_flow_ref && issuance.signup_completed_at.nil?)

      facts = [issuance.confirmed_at, issuance.expires_at, issuance.signup_completed_at, binding_deadline]
      deadline = facts.compact.max + retention_after
      return :pending if deadline > now
      return :held if issuance.client.client_retention_holds.active_at(now).exists? ||
        AppEnforcementCase.principal_effect_blocking?(issuance.client.public_id, :withdrawal_purge_blocked) ||
        AppEnforcementCase.principal_effect_blocking?(issuance.client.public_id, :principal_hard_delete_blocked)

      events = confirmed_audit_events(issuance)
      return :undelivered if events.empty? || events.any? { |event| event.delivered_at.nil? }

      refs = events.filter_map(&:credential_ref)
      return :dependent if ClientSecretSignInReceipt.exists?(credential_ref: refs)
      return :undelivered unless durable_events?(events)
      return :undelivered unless durable_credential_purges?(issuance, refs)

      delete_with_audit!(issuance, executor_job_id, now)
    end

    def confirmed_audit_events(issuance)
      events = ClientSecretAuditOutbox.where(
        client_ref: issuance.client.public_id, operation_ref: issuance.origin_operation_id,
        event_name: %w(secret.storage_declared secret.created), occurred_at: issuance.confirmed_at,
      ).lock.to_a
      declarations = events.select { |event| event.event_name == "secret.storage_declared" }
      created = events.select { |event| event.event_name == "secret.created" }
      refs = created.filter_map(&:credential_ref)
      refs.uniq!
      return [] unless declarations.one? && declarations.first.item_count == issuance.planned_count &&
        declarations.first.credential_ref.nil? && created.size == issuance.planned_count &&
        refs.size == issuance.planned_count

      if issuance.sign_up_flow_ref
        completed = ClientSecretAuditOutbox.where(
          client_ref: issuance.client.public_id, operation_ref: issuance.origin_operation_id,
          event_name: "secret.signup_completed", occurred_at: issuance.signup_completed_at,
          item_count: issuance.planned_count,
        ).lock.to_a
        return [] if completed.empty?

        events += completed
      end
      events
    end

    def durable_credential_purges?(issuance, refs)
      refs.all? do |ref|
        source = ClientSecretAuditOutbox.where(
          client_ref: issuance.client.public_id, credential_ref: ref, event_name: "secret.purged",
        ).lock.to_a
        next false if source.any? { |event| event.delivered_at.nil? }
        next false if source.any? && !durable_events?(source)

        ChronicleRecord.connected_to(role: :writing) do
          Chronicle.where(action: "secret.purged", result: "succeeded")
            .exists?(["metadata @> ?::jsonb", { client_ref: issuance.client.public_id, credential_ref: ref }.to_json])
        end
      end
    end

    def omitted_binding(issuance)
      if issuance.sign_up_flow_ref
        ClientSignUpFlow.lock.find_by(public_id: issuance.sign_up_flow_ref, principal_id: issuance.client_id)
      elsif issuance.browser_session_ref
        ClientToken.lock.find_by(public_id: issuance.browser_session_ref, user_id: issuance.client_id)
      else
        raise ArgumentError, "Omitted allocation requires its original session or signup flow binding"
      end
    end

    def purge_omitted!(issuance, executor_job_id, retention_after, binding_deadline)
      issuance.lock!
      now = Client.database_now
      return :pending unless issuance.state(at: now) == :omitted
      return :dependent if ClientSecretCredential.exists?(issuance_id: issuance.id) ||
        (issuance.sign_up_flow_ref && issuance.signup_completed_at.nil?)

      deadline = [issuance.created_at, issuance.signup_completed_at, binding_deadline].compact.max + retention_after
      return :pending if deadline > now
      return :held if issuance.client.client_retention_holds.active_at(now).exists? ||
        AppEnforcementCase.principal_effect_blocking?(issuance.client.public_id, :withdrawal_purge_blocked) ||
        AppEnforcementCase.principal_effect_blocking?(issuance.client.public_id, :principal_hard_delete_blocked)

      events = omitted_audit_events(issuance)
      return :undelivered if events.empty? || events.any? { |event| event.delivered_at.nil? }
      return :undelivered unless durable_events?(events)

      delete_with_audit!(issuance, executor_job_id, now)
    end

    def omitted_audit_events(issuance)
      events = ClientSecretAuditOutbox.where(
        client_ref: issuance.client.public_id, operation_ref: issuance.origin_operation_id,
        credential_ref: nil, event_name: "secret.issuance_omitted", item_count: 0,
        reason: "capacity_full", occurred_at: issuance.created_at,
      ).lock.to_a
      return events if events.empty?

      if issuance.sign_up_flow_ref
        completed = ClientSecretAuditOutbox.where(
          client_ref: issuance.client.public_id, operation_ref: issuance.origin_operation_id,
          event_name: "secret.signup_completed", occurred_at: issuance.signup_completed_at, item_count: 0,
        ).lock.to_a
        return [] if completed.empty?

        events += completed
      end
      events
    end

    def delete_with_audit!(issuance, executor_job_id, now)
      operation = issuance.origin_operation_id
      client_ref = issuance.client.public_id
      count = issuance.planned_count
      snapshot = {
        issuance_origin: issuance.origin,
        issuance_browser_session_ref: issuance.browser_session_ref,
        issuance_sign_up_flow_ref: issuance.sign_up_flow_ref,
      }
      issuance.delete
      ClientSecretAuditOutbox.record!(
        actor_context: ActorValuesContext.empty, client_ref: client_ref, operation_ref: operation,
        occurred_at: now, event_name: "secret.issuance_purged", item_count: count,
        executor_job_id: executor_job_id, **snapshot,
      )
      :purged
    end

    def durable_events?(events)
      ChronicleRecord.connected_to(role: :writing) do
        durable = Chronicle.where(event_uuid: events.map(&:event_id)).index_by(&:event_uuid)
        events.all? do |event|
          recorded = durable[event.event_id]
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
end
