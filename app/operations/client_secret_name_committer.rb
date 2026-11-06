# frozen_string_literal: true

class ClientSecretNameCommitter
  # An enclosing OP transaction would defer the evidence consumption while the independent
  # Zenith name and audit commit. Refuse instead of reporting a committed rename.
  class TransactionConflict < ArgumentError; end

  class Denied < StandardError; end

  class DependencyFailure < StandardError; end

  class InvalidName < ArgumentError; end

  class << self
    public

    def call!(actor_context:, token:, credential:, name:, step_up_evidence: nil)
      validate_name!(name)
      validate_binding!(actor_context, token, credential)
      require_independent_ticket_commit!

      AppZenithRecord.connected_to(role: :writing) do
        actor_context.subject.with_lock do
          rename!(actor_context, token, credential, name, step_up_evidence)
        end
      end
    rescue ActiveRecord::StatementInvalid, ActiveRecord::ConnectionNotEstablished => e
      raise DependencyFailure, "Secret name storage is unavailable: #{e.class}"
    end

    private

    # Evidence consumption precedes the Zenith rename, so it must own its commit.
    # Checked before any lock or evidence consumption.
    def require_independent_ticket_commit!
      OpBaseAppRecord.connected_to(role: :writing) do
        connection = OpBaseAppRecord.lease_connection
        if connection.transaction_open?
          raise TransactionConflict, "Secret rename requires an independent OP commit"
        end
      end
    end

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

    def rename!(actor_context, token, credential, name, step_up_evidence)
      actor = actor_context.subject
      raise Denied, "Secret rename actor is unavailable" unless actor.login_allowed?

      owned = ClientSecretCredential.lock.find_by(
        id: credential.id, client_id: actor.id, public_id: credential.public_id,
      )
      unless owned && ClientSecretCredentialPolicy.new(owned, user: actor).apply(:update?) &&
          owned.available_at?(at: ClientSecretCredential.database_now)
        raise Denied, "Secret rename credential is unavailable"
      end

      OpBaseAppRecord.connected_to(role: :writing) do
        ClientToken.transaction do
          device = token.device_session_record!
          device.with_lock do
            raise Denied, "Secret rename device is unavailable" unless device.usable? && device.user_id == actor.id

            session = verify_session!(actor, token)
            unless session.device_session_id == device.id && device.current_refresh_token_id == session.id
              raise Denied, "Secret rename session binding changed"
            end

            verify_step_up!(actor, session, step_up_evidence)
          end
        end
      end

      owned.update!(name: name)
      ClientSecretAuditOutbox.record!(
        actor_context: actor_context, client_ref: actor.public_id, credential_ref: owned.public_id,
        operation_ref: SecureRandom.uuid, occurred_at: ClientSecretCredential.database_now,
        event_name: "secret.renamed",
      )
      owned
    rescue TokenStatusManagement::StepUpEvidenceUnavailable => e
      raise Denied, e.message
    end

    def verify_session!(actor, token)
      locked_token = ClientToken.lock.find_by(id: token.id, user_id: actor.id, public_id: token.public_id)
      raise Denied, "Secret rename session is unavailable" unless locked_token

      now = ClientToken.database_now
      raise Denied, "Secret rename session is unavailable" unless locked_token.active_status?(now)

      locked_token
    end

    def verify_step_up!(actor, token, evidence)
      return if StepUpEvidenceVerifier.call(evidence:, actor:, token:)

      raise TokenStatusManagement::StepUpEvidenceUnavailable, "Secret rename requires current Step-Up"
    end
  end
end
