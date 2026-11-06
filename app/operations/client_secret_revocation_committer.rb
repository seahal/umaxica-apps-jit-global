# frozen_string_literal: true

class ClientSecretRevocationCommitter
  class Denied < StandardError; end

  class DependencyFailure < StandardError; end

  class << self
    public

    def call!(actor_context:, token:, credential:, purge_after:, step_up_evidence: nil)
      unless purge_after.is_a?(ActiveSupport::Duration) && purge_after.value.finite? && purge_after.value.positive?
        raise ArgumentError, "Secret retirement requires an explicit positive finite retention duration"
      end

      validate_binding!(actor_context, token, credential)

      AppZenithRecord.connected_to(role: :writing) do
        actor_context.subject.with_lock(requires_new: true) do
          revoke!(actor_context, token, credential, purge_after, step_up_evidence)
        end
      end
    rescue ActiveRecord::StatementInvalid, ActiveRecord::ConnectionNotEstablished => e
      raise DependencyFailure, "Secret revocation storage is unavailable: #{e.class}"
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

    def revoke!(context, token, credential, purge_after, step_up_evidence)
      actor = context.subject
      raise Denied, "Secret revocation actor is unavailable" unless actor.login_allowed?

      owned = ClientSecretCredential.lock.find_by(
        id: credential.id, client_id: actor.id, public_id: credential.public_id,
      )
      unless owned && ClientSecretCredentialPolicy.new(owned, user: actor).apply(:destroy?)
        raise Denied, "Secret revocation credential is unavailable"
      end
      raise Denied, "Secret revocation would remove a required capability" unless
        AuthMethodGuard.can_remove_secret_credential?(actor, owned)

      now = ClientSecretCredential.database_now
      if owned.revoked_at && owned.lapsed?(now)
        authorize_session!(actor, token, evidence: step_up_evidence)
        return owned
      end

      unless owned.available_at?(at: now)
        raise Denied, "Secret revocation would remove an unavailable or last login credential"
      end
      raise Denied, "Secret creation time is ahead of the writer clock" if owned.created_at > now

      purge_at = (now + purge_after).round(6)
      raise ArgumentError, "Secret retention must advance the database timestamp" unless purge_at > now

      authorize_session!(actor, token, evidence: step_up_evidence)
      owned.commit_management_revocation!(actor_context: context, at: now, purge_at: purge_at)
    rescue ClientSecretCredential::InvalidTransition, TokenStatusManagement::StepUpEvidenceUnavailable => e
      raise Denied, e.message
    end

    def authorize_session!(actor, token, evidence:)
      OpBaseAppRecord.connected_to(role: :writing) do
        ClientToken.transaction do
          device = token.device_session_record!
          device.with_lock do
            raise Denied, "Secret revocation device is unavailable" unless device.usable? && device.user_id == actor.id

            session = verify_session!(actor, token)
            unless session.device_session_id == device.id && device.current_refresh_token_id == session.id
              raise Denied, "Secret revocation session binding changed"
            end

            verify_step_up!(actor, session, evidence)
          end
        end
      end
    end

    def verify_session!(actor, token)
      current = ClientToken.lock.find_by(id: token.id, user_id: actor.id, public_id: token.public_id)
      raise Denied, "Secret revocation session is unavailable" unless current

      now = ClientToken.database_now
      raise Denied, "Secret revocation session is unavailable" unless current.active_status?(now)

      current
    end

    def verify_step_up!(actor, token, evidence)
      return if StepUpEvidenceVerifier.call(evidence:, actor:, token:)

      raise TokenStatusManagement::StepUpEvidenceUnavailable, "Secret revocation requires current Step-Up"
    end
  end
end
