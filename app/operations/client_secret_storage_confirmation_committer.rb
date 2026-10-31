# frozen_string_literal: true

class ClientSecretStorageConfirmationCommitter
  class Denied < StandardError; end

  class InvalidState < StandardError; end

  class DependencyFailure < StandardError; end

  class << self
    public

    def call!(actor_context:, token:, issuance:)
      unless actor_context.is_a?(ActorValuesContext) && actor_context.client? && actor_context.tld == :app &&
          actor_context.surface == :base && actor_context.subject.is_a?(Client) && actor_context.subject.persisted? &&
          token.is_a?(ClientToken) && token.persisted? && issuance.is_a?(ClientSecretIssuance) && issuance.persisted?
        raise Denied, "Secret confirmation requires a bound Base app Client, session and issuance"
      end

      AppZenithRecord.connected_to(role: :writing) do
        actor_context.subject.with_lock(requires_new: true) { confirm!(actor_context, token, issuance) }
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

    def confirm!(context, token, issuance)
      actor = context.subject
      raise Denied, "Secret confirmation actor is unavailable" unless actor.login_allowed?

      owned = ClientSecretIssuance.lock.find_by(id: issuance.id, public_id: issuance.public_id, client_id: actor.id)
      unless owned && owned.browser_session_ref == token.public_id && owned.sign_up_flow_ref.nil?
        raise Denied, "Secret confirmation belongs to another authorization context"
      end

      confirm_owned_batch!(context, owned, Client.database_now, token: token)
    end

    def confirm_owned_batch!(context, owned, now, token: nil)
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
        authorize_confirmation!(actor, token, owned, consume: false) if token
        return owned
      end
      if candidates.any? { |candidate|
        candidate.confirmed_at || candidate.claimed_at || candidate.revoked_at ||
            candidate.claim_operation_id || !candidate.accessible?(now)
      }
        raise InvalidState, "pending Secret issuance contains a terminal candidate"
      end

      authorize_confirmation!(actor, token, owned, consume: true) if token
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

    def authorize_confirmation!(actor, token, issuance, consume:)
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

            requirement = verify_step_up!(actor, current, issuance)
            current.consume_step_up_evidence!(requirement: requirement) if consume
          end
        end
      end
    rescue TokenStatusManagement::StepUpEvidenceUnavailable
      raise Denied, "Secret confirmation requires current scoped Step-Up"
    end

    def verify_step_up!(actor, token, issuance)
      scope = (issuance.origin == "manual") ? "settings_secret_credential" : "settings_passkey"
      requirement = StepUpRequirement.new(
        scope: scope, step_up_required: true, allowed_methods: %i(passkey totp email_otp),
        phishing_resistant_required: false, user_verification_required: false,
        full_reauthentication_required: false, purpose: "step_up", audience: "step_up:app",
        session_binding: token.public_id,
        token_binding: token.public_id, require_session_binding: true, ttl: StepUpRequirement::DEFAULT_TTL,
        actor_ref: actor.public_id, resource_ref: issuance.public_id, tenant_ref: nil,
      )
      now = ClientToken.database_now
      unless token.active_status?(now) &&
          StepUpResolver.call(token: token, requirement: requirement, now: now).satisfied?
        raise Denied, "Secret confirmation requires current scoped Step-Up"
      end

      requirement
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
