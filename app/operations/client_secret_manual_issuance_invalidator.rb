# frozen_string_literal: true

class ClientSecretManualIssuanceInvalidator
  class Denied < StandardError; end

  class InvalidState < StandardError; end

  class << self
    public

    def call!(actor_context:, token:, issuance:, purge_after:)
      invalidate!(actor_context, token, issuance, purge_after, "flow_canceled")
    end

    def call_for_payload_failure!(actor_context:, token:, issuance:, purge_after:)
      invalidate!(actor_context, token, issuance, purge_after, "payload_unavailable")
    end

    def call_for_sign_up_payload_failure!(flow:, nonce:, issuance:, purge_after:)
      unless purge_after.is_a?(ActiveSupport::Duration) && purge_after.value.finite? && purge_after.value.positive?
        raise ArgumentError, "Secret payload retirement requires explicit positive finite retention"
      end

      ClientSecretPasskeyReservationIssuer.with_sign_up_delivery!(
        flow: flow, nonce: nonce, issuance: issuance,
      ) do |owned, context, now|
        unless owned.state(at: now) == :pending_presentation
          raise Denied, "Secret payload retirement requires an unpresented signup allocation"
        end

        invalidate_pending!(context, owned, now, purge_after, "payload_unavailable")
      end
    end

    private

    def invalidate!(actor_context, token, issuance, purge_after, reason)
      validate_binding!(actor_context, token, issuance, purge_after)
      AppTicketRecord.connected_to(role: :writing) do
        ClientToken.transaction do
          AppZenithRecord.connected_to(role: :writing) do
            actor_context.subject.with_lock(requires_new: true) do
              cancel!(actor_context, token, issuance, purge_after, reason)
            end
          end
        end
      end
    end

    def validate_binding!(context, token, issuance, duration)
      unless context.is_a?(ActorValuesContext) && context.client? && context.tld == :app &&
          context.surface == :base && context.subject.is_a?(Client) && context.subject.persisted? &&
          token.is_a?(ClientToken) && token.persisted? && issuance.is_a?(ClientSecretIssuance) && issuance.persisted?
        raise Denied, "Secret cancellation requires a bound Base app Client, session and issuance"
      end
      return if duration.is_a?(ActiveSupport::Duration) && duration.value.finite? && duration.value.positive?

      raise ArgumentError, "Secret cancellation requires an explicit positive finite retention duration"
    end

    def cancel!(context, token, issuance, duration, reason)
      actor = context.subject
      raise Denied, "Secret cancellation actor is unavailable" unless actor.login_allowed?

      owned = ClientSecretIssuance.lock.find_by(id: issuance.id, public_id: issuance.public_id, client_id: actor.id)
      raise Denied, "Secret cancellation issuance is unavailable" unless owned

      current = verify_session!(
        actor, token,
        (owned.origin == "manual") ? "settings_secret_credential" : "settings_passkey",
      )
      unless owned.browser_session_ref == current.public_id &&
          owned.sign_up_flow_ref.nil?
        raise Denied, "Secret cancellation issuance belongs to another authorization context"
      end

      now = Client.database_now
      case owned.state(at: now)
      when :canceled, :expired
        owned
      when :confirmed, :omitted
        raise Denied, "terminal Secret issuance cannot be canceled"
      when :pending_presentation, :pending_confirmation
        invalidate_pending!(context.with(subject: actor), owned, now, duration, reason)
      else
        raise InvalidState, "unsupported Secret issuance state"
      end
    end

    def invalidate_pending!(context, issuance, now, duration, reason)
      ClientSecretCapacityQuery.call(client: context.subject, at: now)
      candidates = ClientSecretCredential.where(issuance_id: issuance.id, client_id: issuance.client_id)
        .order(:id).lock.to_a
      finalized =
        candidates.any? do |candidate|
          candidate.confirmed_at || candidate.claimed_at || candidate.claim_operation_id || candidate.revoked_at
        end
      if candidates.length > issuance.planned_count || finalized
        raise InvalidState, "pending Secret issuance contains an inconsistent candidate set"
      end

      purge_at = (now + duration).round(6)
      raise ArgumentError, "Secret cancellation retention must advance the database timestamp" unless purge_at > now

      ClientSecretAuditOutbox.record!(
        actor_context: context, client_ref: context.subject.public_id, operation_ref: issuance.origin_operation_id,
        occurred_at: now, event_name: "secret.issuance_canceled", reason: reason,
        item_count: issuance.planned_count,
      )
      candidates.each do |candidate|
        candidate.update!(discard_at: now, purge_eligible_at: purge_at)
        ClientSecretAuditOutbox.record!(
          actor_context: context, client_ref: context.subject.public_id, credential_ref: candidate.public_id,
          operation_ref: issuance.origin_operation_id, occurred_at: now,
          event_name: "secret.discarded", reason: reason,
        )
      end
      issuance.update!(canceled_at: now, encrypted_payload: nil, discard_at: now, purge_eligible_at: purge_at)
      ClientSecretCapacityQuery.call(client: context.subject, at: now)
      issuance
    end

    def verify_session!(actor, token, scope)
      current = ClientToken.lock.find_by(id: token.id, public_id: token.public_id, user_id: actor.id)
      raise Denied, "Secret cancellation session is unavailable" unless current

      now = ClientToken.database_now
      requirement = StepUpRequirement.new(
        scope: scope, step_up_required: true, allowed_methods: %i(passkey totp email_otp),
        phishing_resistant_required: false, user_verification_required: false,
        full_reauthentication_required: false, purpose: "step_up", audience: "step_up:app",
        session_binding: current.public_id, token_binding: current.public_id,
        require_session_binding: true, ttl: StepUpRequirement::DEFAULT_TTL,
        actor_ref: actor.public_id, resource_ref: nil, tenant_ref: nil,
      )
      unless current.currently_usable?(now) && !current.restricted? &&
          StepUpResolver.call(token: current, requirement: requirement, now: now).satisfied?
        raise Denied, "Secret cancellation requires current scoped Step-Up"
      end

      current
    end
  end
end
