# frozen_string_literal: true

class ClientSecretRevocationCommitter
  class Denied < StandardError; end

  class << self
    public

    def call!(actor_context:, token:, credential:, purge_after:)
      unless purge_after.is_a?(ActiveSupport::Duration) && purge_after.value.finite? && purge_after.value.positive?
        raise ArgumentError, "Secret retirement requires an explicit positive finite retention duration"
      end

      validate_binding!(actor_context, token, credential)

      # Match management's actor-before-session-before-credential lock order.
      # Ticket is read/locked only; lifecycle and source audit commit on Zenith.
      AppTicketRecord.connected_to(role: :writing) do
        ClientToken.transaction do
          AppZenithRecord.connected_to(role: :writing) do
            actor_context.subject.with_lock(requires_new: true) do
              revoke!(actor_context, token, credential, purge_after)
            end
          end
        end
      end
    end

    private

    def validate_binding!(actor_context, token, credential)
      unless actor_context.is_a?(ActorValuesContext) && actor_context.client? &&
          actor_context.tld == :app && actor_context.surface == :base &&
          actor_context.subject.is_a?(Client) && actor_context.subject.persisted? &&
          token.is_a?(ClientToken) && token.persisted? &&
          credential.is_a?(ClientSecretCredential) && credential.persisted?
        raise Denied, "Secret revocation requires a bound Base app actor and session"
      end
    end

    def revoke!(context, token, credential, purge_after)
      actor = context.subject
      raise Denied, "Secret revocation actor is unavailable" unless actor.login_allowed?

      verify_session!(actor, token)
      owned = ClientSecretCredential.lock.find_by(
        id: credential.id, client_id: actor.id, public_id: credential.public_id,
      )
      unless owned && ClientSecretCredentialPolicy.new(owned, user: actor).apply(:destroy?)
        raise Denied, "Secret revocation credential is unavailable"
      end

      now = ClientSecretCredential.database_now
      return owned if owned.revoked_at && owned.lapsed?(now)

      unless owned.available_at?(at: now)
        raise Denied, "Secret revocation would remove an unavailable or last login credential"
      end
      raise Denied, "Secret creation time is ahead of the writer clock" if owned.created_at > now

      purge_at = (now + purge_after).round(6)
      raise ArgumentError, "Secret retention must advance the database timestamp" unless purge_at > now

      owned.commit_management_revocation!(actor_context: context, at: now, purge_at: purge_at)
    rescue ClientSecretCredential::InvalidTransition => e
      raise Denied, e.message
    end

    def verify_session!(actor, token)
      current = ClientToken.lock.find_by(id: token.id, user_id: actor.id, public_id: token.public_id)
      raise Denied, "Secret revocation session is unavailable" unless current

      now = ClientToken.database_now
      requirement = StepUpRequirement.new(
        scope: "settings_secret_credential", step_up_required: true, allowed_methods: %i(passkey totp email_otp),
        phishing_resistant_required: false, user_verification_required: false,
        full_reauthentication_required: false, purpose: "step_up", audience: "step_up:app",
        session_binding: current.public_id, token_binding: current.public_id, require_session_binding: true,
        ttl: StepUpRequirement::DEFAULT_TTL,
        actor_ref: actor.public_id, resource_ref: nil, tenant_ref: nil,
      )
      unless current.currently_usable?(now) && !current.restricted? &&
          StepUpResolver.call(token: current, requirement: requirement, now: now).satisfied?
        raise Denied, "Secret revocation requires current scoped Step-Up"
      end
    end
  end
end
