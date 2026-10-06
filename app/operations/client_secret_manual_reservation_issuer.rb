# frozen_string_literal: true

# Reserves capacity for an explicit, server-identified management operation.
# This step does not generate candidates or plaintext and is not an HTTP entry.
class ClientSecretManualReservationIssuer
  class Denied < StandardError; end

  class CapacityFull < StandardError; end

  class << self
    public

    def call!(actor_context:, token:, operation_id:, expires_after:)
      validate_input!(actor_context, token, operation_id, expires_after)

      # All capacity changes lock Client first. Ticket is read/locked only and
      # remains locked until the Zenith reservation and source audit commit.
      AppTicketRecord.connected_to(role: :writing) do
        ClientToken.transaction do
          AppZenithRecord.connected_to(role: :writing) do
            actor_context.subject.with_lock(requires_new: true) do
              reserve!(actor_context, token, operation_id, expires_after)
            end
          end
        end
      end
    end

    private

    def validate_input!(context, token, operation_id, duration)
      unless context.is_a?(ActorValuesContext) && context.client? && context.tld == :app &&
          context.surface == :base && context.subject.is_a?(Client) && context.subject.persisted? &&
          token.is_a?(ClientToken) && token.persisted?
        raise Denied, "Secret reservation requires a bound Base app Client and session"
      end
      unless operation_id.is_a?(String) && operation_id.valid_encoding? && operation_id.ascii_only? &&
          /\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/.match?(operation_id)
        raise ArgumentError, "Secret reservation requires a server-issued operation UUID"
      end
      return if duration.is_a?(ActiveSupport::Duration) && duration.value.finite? && duration.value.positive?

      raise ArgumentError, "Secret reservation requires an explicit positive finite duration"

    end

    def reserve!(context, token, operation_id, duration)
      actor = context.subject
      unless actor.login_allowed? && ClientSecretCredentialPolicy.new(
        ClientSecretCredential,
        user: actor,
      ).apply(:create?)
        raise Denied, "Secret reservation actor is unavailable"
      end

      current = verify_session!(actor, token)
      if ClientSecretAuditOutbox.exists?(operation_ref: operation_id, event_name: "secret.issuance_purged")
        raise Denied, "Secret reservation operation has already been retired"
      end

      prior = ClientSecretIssuance.where(origin_operation_id: operation_id).order(attempt_number: :desc).lock.first
      if prior
        unless prior.client_id == actor.id && prior.browser_session_ref == current.public_id &&
            prior.sign_up_flow_ref.nil? && prior.origin == "manual"
          raise Denied, "Secret reservation operation belongs to another authorization context"
        end

        prior.state(at: Client.database_now)
        return prior
      end

      now = Client.database_now
      capacity = ClientSecretCapacityQuery.call(client: actor, at: now)
      raise CapacityFull, "twenty active Secrets prevent manual addition" if capacity.manual_count.zero?

      deadline = [now + duration, current.last_step_up_at + StepUpRequirement::DEFAULT_TTL].min.round(6)
      raise ArgumentError, "Secret reservation duration must advance the database timestamp" unless deadline > now

      issuance = ClientSecretIssuance.create!(
        client: actor, origin_operation_id: operation_id, origin: "manual", attempt_number: 1,
        browser_session_ref: current.public_id, planned_count: 1, expires_at: deadline,
        created_at: now, updated_at: now,
      )
      ClientSecretCapacityQuery.call(client: actor, at: now)
      ClientSecretAuditOutbox.record!(
        actor_context: context.with(subject: actor), client_ref: actor.public_id,
        operation_ref: operation_id, occurred_at: now, event_name: "secret.issuance_started",
        reason: "manual", item_count: issuance.planned_count,
      )
      issuance
    end

    def verify_session!(actor, token)
      current = ClientToken.lock.find_by(id: token.id, user_id: actor.id, public_id: token.public_id)
      raise Denied, "Secret reservation session is unavailable" unless current

      now = ClientToken.database_now
      requirement = StepUpRequirement.new(
        scope: "settings_secret_credential", step_up_required: true, allowed_methods: %i(passkey totp email_otp),
        phishing_resistant_required: false, user_verification_required: false,
        full_reauthentication_required: false, purpose: "step_up", audience: "step_up:app",
        session_binding: current.public_id, token_binding: current.public_id,
        require_session_binding: true, ttl: StepUpRequirement::DEFAULT_TTL,
        actor_ref: actor.public_id, resource_ref: nil, tenant_ref: nil,
      )
      unless current.currently_usable?(now) && !current.restricted? &&
          StepUpResolver.call(token: current, requirement: requirement, now: now).satisfied?
        raise Denied, "Secret reservation requires current scoped Step-Up"
      end

      current
    end
  end
end
