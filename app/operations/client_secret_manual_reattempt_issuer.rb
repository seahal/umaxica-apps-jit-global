# frozen_string_literal: true

# Creates one successor for a payload-failed manual allocation. The predecessor
# and its exact next attempt are resolved under the Client lock, so a duplicate
# POST cannot select an unrelated newer allocation.
class ClientSecretManualReattemptIssuer
  class Denied < StandardError; end

  class << self
    def call!(actor_context:, token:, predecessor:, purge_after:)
      validate_input!(actor_context, token, predecessor, purge_after)

      AppTicketRecord.connected_to(role: :writing) do
        ClientToken.transaction do
          AppZenithRecord.connected_to(role: :writing) do
            actor_context.subject.with_lock(requires_new: true) do
              create_or_return_successor!(actor_context, token, predecessor)
            end
          end
        end
      end
    end

    private

    def validate_input!(context, token, predecessor, duration)
      unless context.is_a?(ActorValuesContext) && context.client? && context.tld == :app &&
          context.surface == :base && context.subject.is_a?(Client) && context.subject.persisted? &&
          token.is_a?(ClientToken) && token.persisted? && predecessor.is_a?(ClientSecretIssuance) &&
          predecessor.persisted?
        raise Denied, "Secret reattempt requires a bound Base app Client, session and predecessor"
      end
      return if duration.is_a?(ActiveSupport::Duration) && duration.value.finite? && duration.value.positive?

      raise ArgumentError, "Secret reattempt requires an explicit positive finite retention"

    end

    def create_or_return_successor!(context, token, predecessor)
      actor = context.subject
      current = ClientToken.lock.find_by(id: token.id, public_id: token.public_id, user_id: actor.id)
      raise Denied, "Secret reattempt session is unavailable" unless current
      raise Denied, "Secret reattempt belongs to another Client" unless predecessor.client_id == actor.id
      raise Denied, "Only manual Secret allocations can be reattempted" unless predecessor.origin == "manual"
      raise Denied,
            "Secret reattempt requires the original session" unless predecessor.browser_session_ref == current.public_id
      raise Denied, "Secret reattempt requires the exact predecessor" unless payload_failed?(predecessor)

      successor_attempt = predecessor.attempt_number + 1
      successor = ClientSecretIssuance.lock.find_by(
        origin_operation_id: predecessor.origin_operation_id,
        attempt_number: successor_attempt,
        client_id: actor.id,
        origin: "manual",
      )
      return successor if successor

      now = Client.database_now
      requirement = StepUpRequirement.new(
        scope: "settings_secret_credential", step_up_required: true, allowed_methods: %i(passkey totp email_otp),
        phishing_resistant_required: false, user_verification_required: false, full_reauthentication_required: false,
        purpose: "step_up", audience: "step_up:app", session_binding: current.public_id,
        token_binding: current.public_id, require_session_binding: true, ttl: StepUpRequirement::DEFAULT_TTL,
        actor_ref: actor.public_id, resource_ref: nil, tenant_ref: nil,
      )
      unless current.currently_usable?(now) && !current.restricted? &&
          StepUpResolver.call(token: current, requirement: requirement, now: now).satisfied?
        raise Denied, "Secret reattempt requires current scoped Step-Up"
      end

      capacity = ClientSecretCapacityQuery.call(client: actor, at: now)
      raise ClientSecretManualReservationIssuer::CapacityFull,
            "twenty active Secrets prevent reattempt" if capacity.manual_count.zero?

      deadline = [now + ClientSecretLifetimesValue.issuance_ttl, current.last_step_up_at + StepUpRequirement::DEFAULT_TTL].min.round(6)
      raise ArgumentError, "Secret reattempt expiry must advance the database timestamp" unless deadline > now

      successor = ClientSecretIssuance.create!(
        client: actor, origin_operation_id: predecessor.origin_operation_id, origin: "manual",
        attempt_number: successor_attempt, browser_session_ref: current.public_id,
        planned_count: predecessor.planned_count, expires_at: deadline, created_at: now, updated_at: now,
      )
      ClientSecretAuditOutbox.record!(
        actor_context: context.with(subject: actor), client_ref: actor.public_id,
        operation_ref: successor.origin_operation_id, occurred_at: now, event_name: "secret.issuance_started",
        reason: "reattempt", item_count: successor.planned_count,
      )
      successor
    end

    def payload_failed?(issuance)
      issuance.canceled_at.present? && ClientSecretAuditOutbox.exists?(
        client_ref: issuance.client.public_id, operation_ref: issuance.origin_operation_id,
        event_name: "secret.issuance_canceled", reason: "payload_unavailable",
        occurred_at: issuance.canceled_at, item_count: issuance.planned_count,
      )
    end
  end
end
