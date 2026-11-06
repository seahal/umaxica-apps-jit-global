# frozen_string_literal: true

class ClientSecretStorageConfirmationCommitter
  # An enclosing OP transaction would defer the evidence consumption while the independent
  # Zenith storage confirmation and audit commit. Refuse instead of reporting a committed Secret.
  class TransactionConflict < ArgumentError; end

  class Denied < StandardError; end

  class InvalidState < StandardError; end

  class DependencyFailure < StandardError; end

  class << self
    public

    def call!(actor_context:, token:, issuance:, step_up_evidence: nil)
      unless actor_context.is_a?(ActorValuesContext) && actor_context.client? && actor_context.tld == :app &&
          actor_context.surface == :base && actor_context.subject.is_a?(Client) && actor_context.subject.persisted? &&
          token.is_a?(ClientToken) && token.persisted? && issuance.is_a?(ClientSecretIssuance) && issuance.persisted?
        raise Denied, "Secret confirmation requires a bound Base app Client, session and issuance"
      end

      require_independent_ticket_commit!

      AppZenithRecord.connected_to(role: :writing) do
        actor_context.subject.with_lock(requires_new: true) do
          confirm!(actor_context, token, issuance, step_up_evidence)
        end
      end
    rescue ActiveRecord::StatementInvalid, ActiveRecord::ConnectionNotEstablished => e
      raise DependencyFailure, "Secret confirmation storage is unavailable: #{e.class}"
    end

    def confirm_for_sign_up!(flow:, nonce:, issuance:)
      ClientSecretPasskeyReservationIssuer.with_sign_up_delivery!(
        flow: flow, nonce: nonce,
        issuance: issuance,
      ) do |owned, context, now|
        confirm_owned_batch!(context, owned, now)
      end
    end

    private

    # The signed-in path consumes evidence in a separate OP commit before the Zenith confirmation.
    # The sign-up path owns the enclosing OP transaction deliberately and does not use this guard.
    def require_independent_ticket_commit!
      OpBaseAppRecord.connected_to(role: :writing) do
        connection = OpBaseAppRecord.lease_connection
        if connection.transaction_open?
          raise TransactionConflict, "Secret confirmation requires an independent OP commit"
        end
      end
    end

    def confirm!(context, token, issuance, step_up_evidence)
      actor = context.subject
      raise Denied, "Secret confirmation actor is unavailable" unless actor.login_allowed?

      owned = ClientSecretIssuance.lock.find_by(id: issuance.id, public_id: issuance.public_id, client_id: actor.id)
      unless owned && owned.browser_session_ref == token.public_id && owned.sign_up_flow_ref.nil?
        raise Denied, "Secret confirmation belongs to another authorization context"
      end

      confirm_owned_batch!(
        context, owned, Client.database_now, token: token, step_up_evidence: step_up_evidence,
      )
    end

    def confirm_owned_batch!(context, owned, now, token: nil, step_up_evidence: nil)
      actor = context.subject
      state = owned.state(at: now)
      unless %i(pending_confirmation confirmed).include?(state)
        raise Denied, "Secret confirmation requires a presented, unexpired issuance"
      end

      candidates = ClientSecretCredential.where(issuance_id: owned.id, client_id: actor.id).order(:id).lock.to_a
      verify_presented_set!(actor, owned, candidates)
      if state == :confirmed
        unless candidates.all? { |candidate| candidate.confirmed_at == owned.confirmed_at }
          raise InvalidState, "confirmed Secret issuance contains an inconsistent candidate set"
        end

        verify_confirmation_audit!(actor, owned, candidates)
        authorize_confirmation!(actor, token, step_up_evidence) if token
        return owned
      end
      if candidates.any? { |candidate|
        candidate.confirmed_at || candidate.claimed_at || candidate.revoked_at ||
            candidate.claim_operation_id || !candidate.accessible?(now)
      }
        raise InvalidState, "pending Secret issuance contains a terminal candidate"
      end

      authorize_confirmation!(actor, token, step_up_evidence) if token
      commit_batch!(context.with(subject: actor), owned, candidates, now)
    end

    def commit_batch!(context, owned, candidates, now)
      actor = context.subject
      ClientSecretCapacityQuery.call(client: actor, at: now)
      ClientSecretAuditOutbox.record!(
        actor_context: context, client_ref: actor.public_id, operation_ref: owned.origin_operation_id,
        occurred_at: now, event_name: "secret.storage_declared", item_count: owned.planned_count,
      )
      owned.update!(confirmed_at: now, encrypted_payload: nil)
      candidates.each do |candidate|
        ClientSecretAuditOutbox.record!(
          actor_context: context, client_ref: actor.public_id, credential_ref: candidate.public_id,
          operation_ref: owned.origin_operation_id, occurred_at: now, event_name: "secret.created",
        )
        candidate.commit_storage_confirmation!(actor_context: context, at: now)
      end
      ClientSecretCapacityQuery.call(client: actor, at: now)
      owned
    end

    def authorize_confirmation!(actor, token, evidence)
      OpBaseAppRecord.connected_to(role: :writing) do
        ClientToken.transaction do
          device = token.device_session_record!
          device.with_lock do
            raise Denied,
                  "Secret confirmation device is unavailable" unless device.usable? && device.user_id == actor.id

            current = ClientToken.lock.find_by(id: token.id, public_id: token.public_id, user_id: actor.id)
            unless current && current.device_session_id == device.id && device.current_refresh_token_id == current.id
              raise Denied, "Secret confirmation session is unavailable"
            end

            verify_step_up!(actor, current, evidence)
          end
        end
      end
    rescue TokenStatusManagement::StepUpEvidenceUnavailable
      raise Denied, "Secret confirmation requires current Step-Up"
    end

    def verify_step_up!(actor, token, evidence)
      return if StepUpEvidenceVerifier.call(evidence:, actor:, token:)

      raise TokenStatusManagement::StepUpEvidenceUnavailable, "Secret confirmation requires current Step-Up"
    end

    def verify_confirmation_audit!(actor, issuance, candidates)
      events = ClientSecretAuditOutbox.where(
        client_ref: actor.public_id, operation_ref: issuance.origin_operation_id, occurred_at: issuance.confirmed_at,
        actor_type: "Client", actor_id: actor.id, actor_public_ref: actor.public_id,
      )
      declarations = events.where(event_name: "secret.storage_declared")
      created_refs = events.where(event_name: "secret.created").pluck(:credential_ref)
      expected_refs = candidates.map(&:public_id)
      unless declarations.count == 1 && declarations.exists?(item_count: issuance.planned_count) &&
          created_refs.length == candidates.length && created_refs.all?(String) &&
          created_refs.sort! == expected_refs.sort!
        raise InvalidState, "confirmed Secret issuance is missing its matching source audit"
      end
    end

    def verify_presented_set!(actor, issuance, candidates)
      references = ClientSecretAuditOutbox.where(
        client_ref: actor.public_id, operation_ref: issuance.origin_operation_id,
        event_name: "secret.presented", occurred_at: issuance.presented_at,
        actor_type: "Client", actor_id: actor.id, actor_public_ref: actor.public_id, item_count: 1,
      ).pluck(:credential_ref)
      expected = candidates.map(&:public_id)
      unless candidates.length == issuance.planned_count && references.length == issuance.planned_count &&
          references.all?(String) && references.sort! == expected.sort!
        raise InvalidState, "Secret confirmation requires the exact audited presentation set"
      end
    end
  end
end
