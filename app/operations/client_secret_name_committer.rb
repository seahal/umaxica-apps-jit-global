# frozen_string_literal: true

class ClientSecretNameCommitter
  class Denied < StandardError; end

  class InvalidName < ArgumentError; end

  class << self
    public

    def call!(actor_context:, token:, credential:, name:)
      validate_name!(name)
      validate_binding!(actor_context, token, credential)

      # Ticket is read/locked only. Its outer transaction keeps the session lock
      # until the source Zenith mutation and outbox have committed together.
      AppTicketRecord.connected_to(role: :writing) do
        ClientToken.transaction do
          AppZenithRecord.connected_to(role: :writing) do
            actor_context.subject.with_lock do
              rename!(actor_context, token, credential, name)
            end
          end
        end
      end
    end

    private

    def validate_name!(name)
      unless name.is_a?(String) && name.valid_encoding? && name.exclude?("\0") &&
          name.present? && name.length <= 255
        raise InvalidName, "Secret name must be a nonempty string of at most 255 characters"
      end
    end

    def validate_binding!(actor_context, token, credential)
      unless actor_context.is_a?(ActorValuesContext) && actor_context.client? &&
          actor_context.tld == :app && actor_context.surface == :base &&
          actor_context.subject.is_a?(Client) && actor_context.subject.persisted? &&
          token.is_a?(ClientToken) && token.persisted? &&
          credential.is_a?(ClientSecretCredential) && credential.persisted?
        raise Denied, "Secret rename requires a bound Base app actor and session"
      end
    end

    def rename!(actor_context, token, credential, name)
      actor = actor_context.subject
      raise Denied, "Secret rename actor is unavailable" unless actor.login_allowed?

      verify_session!(actor, token)

      owned = ClientSecretCredential.lock.find_by(
        id: credential.id, client_id: actor.id, public_id: credential.public_id,
      )
      unless owned && ClientSecretCredentialPolicy.new(owned, user: actor).apply(:update?) &&
          owned.available_at?(at: ClientSecretCredential.database_now)
        raise Denied, "Secret rename credential is unavailable"
      end

      owned.update!(name: name)
      ClientSecretAuditOutbox.record!(
        actor_context: actor_context, client_ref: actor.public_id, credential_ref: owned.public_id,
        operation_ref: SecureRandom.uuid, occurred_at: ClientSecretCredential.database_now,
        event_name: "secret.renamed",
      )
      owned
    end

    def verify_session!(actor, token)
      locked_token = ClientToken.lock.find_by(id: token.id, user_id: actor.id, public_id: token.public_id)
      raise Denied, "Secret rename session is unavailable" unless locked_token

      now = ClientToken.database_now
      requirement = StepUpRequirement.new(
        scope: "settings_secret_credential", step_up_required: true, allowed_methods: %i(passkey totp email_otp),
        phishing_resistant_required: false, user_verification_required: false,
        full_reauthentication_required: false, purpose: "step_up", audience: "step_up:app",
        session_binding: locked_token.public_id, token_binding: locked_token.public_id,
        require_session_binding: true, ttl: StepUpRequirement::DEFAULT_TTL,
        actor_ref: actor.public_id, resource_ref: nil, tenant_ref: nil,
      )
      unless locked_token.currently_usable?(now) && !locked_token.restricted? &&
          StepUpResolver.call(token: locked_token, requirement: requirement, now: now).satisfied?
        raise Denied, "Secret rename requires current scoped Step-Up"
      end

    end
  end
end
