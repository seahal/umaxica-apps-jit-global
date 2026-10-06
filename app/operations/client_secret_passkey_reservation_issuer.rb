# frozen_string_literal: true

require "digest"

# The persisted registration identifies the batch. Browser input never selects an operation UUID.
class ClientSecretPasskeyReservationIssuer
  class Denied < StandardError; end

  class << self
    public

    def terminate_sign_up!(flow:, purge_after:)
      unless flow.is_a?(ClientSignUpFlow) && purge_after.is_a?(ActiveSupport::Duration) &&
          purge_after.value.finite? && purge_after.value.positive?
        raise Denied, "Secret signup retirement requires its durable flow and finite retention"
      end

      AppZenithRecord.connected_to(role: :writing) do
        Client.find(flow.principal_id).with_lock do
          AppTicketRecord.connected_to(role: :writing) do
            ClientSignUpFlow.transaction do
              current = ClientSignUpFlow.lock.find_by!(id: flow.id, public_id: flow.public_id)
              reason =
                case ClientSignUpFlow::STATUS_NAMES.fetch(current.status_id)
                when "CANCELLED" then "flow_canceled"
                when "EXPIRED" then "flow_expired"
                when "FAILED" then "flow_failed"
                when "HALTED" then "flow_halted"
                when "FINALIZED", "SIGN_IN_HANDOFF_PENDING" then "flow_halted"
                else raise Denied, "Secret signup retirement requires a confirmed terminal flow"
                end
              retire_signup_batch!(current, reason, purge_after)
            end
          end
        end
      end
    end

    def complete_sign_up!(flow:)
      raise Denied, "Secret activation requires an app signup flow" unless flow.is_a?(ClientSignUpFlow)

      AppZenithRecord.connected_to(role: :writing) do
        actor = Client.find(flow.principal_id)
        actor.with_lock do
          AppTicketRecord.connected_to(role: :writing) do
            ClientSignUpFlow.transaction do
              current = ClientSignUpFlow.lock.find_by!(id: flow.id, public_id: flow.public_id, principal_id: actor.id)
              raise Denied, "Secret activation requires completed signup" unless current.sign_up_completed?

              owned = ClientSecretIssuance.lock.where(
                sign_up_flow_ref: current.public_id, client_id: actor.id,
              ).order(attempt_number: :desc).first
              return unless owned
              return owned if owned.signup_completed_at
              unless [ClientStatus::ACTIVE, ClientStatus::VERIFIED_WITH_SIGN_UP].include?(actor.status_id) &&
                  actor.login_allowed?
                raise Denied, "Secret activation requires committed Client registration"
              end
              unless owned.origin == "passkey_registration" && (owned.planned_count.zero? || owned.confirmed_at)
                raise Denied, "Secret activation requires a saved batch or normal omission"
              end

              now = Client.database_now
              ClientSecretAuditOutbox.record!(
                actor_context: ActorValuesContext.empty.with(
                  subject: actor, actor_type: :client, tld: :app, surface: :sign,
                ),
                client_ref: actor.public_id, operation_ref: owned.origin_operation_id, occurred_at: now,
                event_name: "secret.signup_completed", reason: "passkey_registration", item_count: owned.planned_count,
              )
              owned.update!(signup_completed_at: now)
              owned
            end
          end
        end
      end
    end

    def with_sign_up_delivery!(flow:, nonce:, issuance:)
      unless flow.is_a?(ClientSignUpFlow) && issuance.is_a?(ClientSecretIssuance)
        raise Denied, "Secret signup delivery requires its durable flow and issuance"
      end

      actor = Client.find(issuance.client_id)
      AppTicketRecord.connected_to(role: :writing) do
        ClientSignUpFlow.transaction do
          AppZenithRecord.connected_to(role: :writing) do
            actor.with_lock do
              current = ClientSignUpFlow.lock.find_by!(id: flow.id, public_id: flow.public_id)
              passkey = actor.client_passkeys.lock.find(current.pending_passkey_registration_id)
              verify_sign_up_registration!(actor, current, passkey, nonce)
              owned = ClientSecretIssuance.lock.find_by!(
                id: issuance.id, public_id: issuance.public_id,
                client_id: actor.id,
              )
              now = Client.database_now
              unless owned.sign_up_flow_ref == current.public_id && owned.browser_session_ref.nil? &&
                  owned.origin_operation_id == registration_operation(passkey) &&
                  owned.origin == "passkey_registration" && owned.expires_at && owned.expires_at > now &&
                  owned.expires_at <= current.expires_at && owned.canceled_at.nil?
                raise Denied, "Secret signup delivery binding or deadline mismatch"
              end

              context = ActorValuesContext.empty.with(subject: actor, actor_type: :client, tld: :app, surface: :sign)
              yield owned, context, now
            end
          end
        end
      end
    rescue ActiveRecord::RecordNotFound
      raise Denied, "Secret signup delivery is unavailable"
    end

    def reattempt_for_sign_up!(flow:, nonce:, predecessor:, expires_after:)
      unless flow.is_a?(ClientSignUpFlow) && flow.persisted? && predecessor.is_a?(ClientSecretIssuance) &&
          predecessor.persisted? && expires_after.is_a?(ActiveSupport::Duration) &&
          expires_after.value.finite? && expires_after.value.positive?
        raise Denied, "Secret signup reattempt requires its durable flow, predecessor and finite deadline"
      end

      actor = Client.find(flow.principal_id)
      AppTicketRecord.connected_to(role: :writing) do
        ClientSignUpFlow.transaction do
          AppZenithRecord.connected_to(role: :writing) do
            actor.with_lock do
              current = ClientSignUpFlow.lock.find_by!(id: flow.id, public_id: flow.public_id)
              registered = actor.client_passkeys.lock.find(current.pending_passkey_registration_id)
              verify_sign_up_registration!(actor, current, registered, nonce)
              reattempt_sign_up!(actor, current, registered, predecessor, expires_after)
            end
          end
        end
      end
    rescue ActiveRecord::RecordNotFound
      raise Denied, "Secret signup reattempt is unavailable"
    end

    def call_for_sign_up!(flow:, nonce:, passkey:, expires_after:)
      unless flow.is_a?(ClientSignUpFlow) && flow.persisted? && passkey.is_a?(ClientPasskey) &&
          expires_after.is_a?(ActiveSupport::Duration) && expires_after.value.finite? && expires_after.value.positive?
        raise Denied, "Secret signup delivery requires its durable registration and finite deadline"
      end

      actor = Client.find(flow.principal_id)
      AppTicketRecord.connected_to(role: :writing) do
        ClientSignUpFlow.transaction do
          AppZenithRecord.connected_to(role: :writing) do
            actor.with_lock do
              current = ClientSignUpFlow.lock.find_by!(id: flow.id, public_id: flow.public_id)
              registered = actor.client_passkeys.lock.find_by!(id: passkey.id, public_id: passkey.public_id)
              verify_sign_up_registration!(actor, current, registered, nonce)
              reserve_sign_up!(actor, current, registered, expires_after)
            end
          end
        end
      end
    rescue ActiveRecord::RecordNotFound
      raise Denied, "Secret signup registration is unavailable"
    end

    def call!(actor_context:, token:, passkey:, expires_after:)
      unless actor_context.is_a?(ActorValuesContext) && actor_context.client? && actor_context.tld == :app &&
          actor_context.subject.is_a?(Client) && token.is_a?(ClientToken) && passkey.is_a?(ClientPasskey)
        raise Denied, "Secret delivery requires its app registration and browser"
      end
      unless expires_after.is_a?(ActiveSupport::Duration) &&
          expires_after.value.finite? && expires_after.value.positive?
        raise ArgumentError, "Secret delivery requires an explicit finite reservation duration"
      end

      AppTicketRecord.connected_to(role: :writing) do
        ClientToken.transaction do
          AppZenithRecord.connected_to(role: :writing) do
            actor_context.subject.with_lock do
              reserve!(actor_context, token, passkey, expires_after)
            end
          end
        end
      end
    end

    private

    def retire_signup_batch!(flow, reason, delay)
      owned = ClientSecretIssuance.lock.where(
        sign_up_flow_ref: flow.public_id, client_id: flow.principal_id,
      ).order(attempt_number: :desc).first
      return unless owned
      raise Denied, "Activated signup credentials cannot be retired as pending" if owned.signup_completed_at

      now = Client.database_now
      return owned if owned.discard_at != Float::INFINITY && owned.discard_at <= now

      actor = owned.client
      context = ActorValuesContext.empty.with(subject: actor, actor_type: :client, tld: :app, surface: :sign)
      candidates = ClientSecretCredential.where(issuance_id: owned.id, client_id: actor.id).order(:id).lock.to_a
      if candidates.any? { |candidate| candidate.claimed_at || candidate.revoked_at }
        raise Denied, "Pending signup cannot contain authenticated or revoked candidates"
      end

      candidates.each do |candidate|
        candidate.update!(discard_at: now, purge_eligible_at: (now + delay).round(6))
        ClientSecretAuditOutbox.record!(
          actor_context: context, client_ref: actor.public_id, credential_ref: candidate.public_id,
          operation_ref: owned.origin_operation_id, occurred_at: now, event_name: "secret.discarded", reason: reason,
        )
      end
      ClientSecretAuditOutbox.record!(
        actor_context: context, client_ref: actor.public_id, operation_ref: owned.origin_operation_id,
        occurred_at: now, event_name: "secret.discarded", reason: reason, item_count: owned.planned_count,
      )
      owned.update!(encrypted_payload: nil, discard_at: now, purge_eligible_at: (now + delay).round(6))
      owned
    end

    def verify_sign_up_registration!(actor, flow, passkey, nonce)
      telephone = actor.client_telephones.lock.find_by(id: flow.pending_contact_id)
      unless actor.status_id == ClientStatus::UNVERIFIED_WITH_SIGN_UP && actor.active? &&
          flow.principal_id == actor.id && flow.nonce_matches?(nonce) &&
          flow.sign_up_checkpoint_pending? && !flow.expired?(ClientSignUpFlow.database_now) &&
          flow.entry_method == "telephone" && flow.pending_contact_type == "telephone" && telephone &&
          telephone.user_telephone_status_id == ClientTelephoneStatus::UNVERIFIED_WITH_SIGN_UP &&
          flow.requirement_cleared?(:otp) && !flow.requirement_cleared?(:passkey) &&
          flow.pending_passkey_registration_id == passkey.id && passkey.status_id == ClientPasskeyStatus::ACTIVE
        raise Denied, "Secret signup delivery requires the same pending Client, contact, browser and Passkey"
      end
    end

    def reserve_sign_up!(actor, flow, passkey, duration)
      operation = registration_operation(passkey)
      verify_uncollected_operation!(operation)
      prior = ClientSecretIssuance.lock.where(
        origin_operation_id: operation, client_id: actor.id, sign_up_flow_ref: flow.public_id,
        browser_session_ref: nil, origin: "passkey_registration",
      ).order(attempt_number: :desc).first
      if prior
        return prior
      end

      now = Client.database_now
      count = ClientSecretCapacityQuery.call(client: actor, at: now).passkey_count
      deadline = [now + duration, flow.expires_at].min.round(6) if count.positive?
      issuance = ClientSecretIssuance.create!(
        client: actor, origin: "passkey_registration", origin_operation_id: operation, attempt_number: 1,
        sign_up_flow_ref: flow.public_id, planned_count: count, expires_at: deadline, created_at: now, updated_at: now,
      )
      ClientSecretAuditOutbox.record!(
        actor_context: ActorValuesContext.empty.with(subject: actor, actor_type: :client, tld: :app, surface: :sign),
        client_ref: actor.public_id, operation_ref: operation, occurred_at: now,
        event_name: count.zero? ? "secret.issuance_omitted" : "secret.issuance_started",
        reason: count.zero? ? "capacity_full" : "passkey_registration", item_count: count,
      )
      ClientSecretCapacityQuery.call(client: actor, at: now)
      issuance
    end

    def reattempt_sign_up!(actor, flow, passkey, predecessor, duration)
      operation = registration_operation(passkey)
      owned = ClientSecretIssuance.lock.find_by(
        id: predecessor.id, public_id: predecessor.public_id, client_id: actor.id,
        sign_up_flow_ref: flow.public_id, browser_session_ref: nil,
        origin: "passkey_registration", origin_operation_id: operation,
      )
      raise Denied, "Secret signup reattempt predecessor is unavailable" unless owned

      latest_attempt = ClientSecretIssuance.where(
        client_id: actor.id, sign_up_flow_ref: flow.public_id, origin_operation_id: operation,
      ).maximum(:attempt_number)
      unless latest_attempt == owned.attempt_number && payload_failed?(owned)
        raise Denied, "Secret signup reattempt requires the exact retired latest allocation"
      end

      successor_attempt = owned.attempt_number + 1
      successor = ClientSecretIssuance.lock.find_by(
        client_id: actor.id, sign_up_flow_ref: flow.public_id, origin_operation_id: operation,
        origin: "passkey_registration", browser_session_ref: nil, attempt_number: successor_attempt,
      )
      return successor if successor

      now = Client.database_now
      count = ClientSecretCapacityQuery.call(client: actor, at: now).passkey_count
      deadline = [now + duration, flow.expires_at].min.round(6) if count.positive?
      successor = ClientSecretIssuance.create!(
        client: actor, origin: "passkey_registration", origin_operation_id: operation,
        attempt_number: successor_attempt, sign_up_flow_ref: flow.public_id, planned_count: count,
        expires_at: deadline, created_at: now, updated_at: now,
      )
      ClientSecretAuditOutbox.record!(
        actor_context: ActorValuesContext.empty.with(
          subject: actor, actor_type: :client, tld: :app, surface: :sign,
        ),
        client_ref: actor.public_id, operation_ref: operation, occurred_at: now,
        event_name: count.zero? ? "secret.issuance_omitted" : "secret.issuance_started",
        reason: count.zero? ? "capacity_full" : "reattempt", item_count: count,
      )
      ClientSecretCapacityQuery.call(client: actor, at: now)
      successor
    end

    def payload_failed?(issuance)
      issuance.canceled_at.present? && ClientSecretAuditOutbox.exists?(
        client_ref: issuance.client.public_id, operation_ref: issuance.origin_operation_id,
        event_name: "secret.issuance_canceled", reason: "payload_unavailable",
        occurred_at: issuance.canceled_at, item_count: issuance.planned_count,
      )
    end

    def registration_operation(passkey)
      hex = Digest::SHA256.hexdigest("app_secret_passkey_registration:#{passkey.public_id}")
      [hex[0, 8], hex[8, 4], hex[12, 4], hex[16, 4], hex[20, 12]].join("-")
    end

    def verify_uncollected_operation!(operation)
      return unless ClientSecretAuditOutbox.exists?(operation_ref: operation, event_name: "secret.issuance_purged")

      raise Denied, "Secret registration allocation has already been retired"

    end

    def authorized_registration!(actor, token, passkey)
      current = ClientToken.lock.find_by(id: token.id, public_id: token.public_id, user_id: actor.id)
      registered = ClientPasskey.lock.find_by(id: passkey.id, public_id: passkey.public_id, user_id: actor.id)
      requirement = StepUpRequirement.new(
        scope: "settings_passkey", step_up_required: true, allowed_methods: %i(passkey totp email_otp),
        phishing_resistant_required: false, user_verification_required: false,
        full_reauthentication_required: false, purpose: "step_up", audience: "step_up:app",
        session_binding: current&.public_id, token_binding: current&.public_id,
        require_session_binding: true, ttl: StepUpRequirement::DEFAULT_TTL,
        actor_ref: actor.public_id, resource_ref: nil, tenant_ref: nil,
      )
      ticket_now = ClientToken.database_now
      unless actor.login_allowed? && current && registered && registered.status_id == ClientPasskeyStatus::ACTIVE &&
          current.currently_usable?(ticket_now) && !current.restricted? &&
          StepUpResolver.call(token: current, requirement: requirement, now: ticket_now).satisfied?
        raise Denied, "Secret distribution requires independent scoped registration Step-Up"
      end

      [current, registered]
    end

    def reserve!(context, token, passkey, duration)
      actor = context.subject
      current, registered = authorized_registration!(actor, token, passkey)

      # A server-derived UUID names exactly this persisted registration, including omission retries.
      operation = registration_operation(registered)
      verify_uncollected_operation!(operation)
      prior = ClientSecretIssuance.lock.find_by(origin_operation_id: operation)
      if prior
        unless prior.client_id == actor.id && prior.browser_session_ref == current.public_id &&
            prior.origin == "passkey_registration" && prior.sign_up_flow_ref.nil?
          raise Denied, "Secret registration batch belongs to another browser"
        end

        return prior
      end
      unless registered.created_at >= current.last_step_up_at && registered.created_at <= Client.database_now
        raise Denied, "Secret distribution requires the registration authorized by this Step-Up"
      end

      now = Client.database_now
      count = ClientSecretCapacityQuery.call(client: actor, at: now).passkey_count
      deadline = [now + duration,
                  current.last_step_up_at + StepUpRequirement::DEFAULT_TTL,].min.round(6) if count.positive?
      issuance = ClientSecretIssuance.create!(
        client: actor, origin: "passkey_registration", origin_operation_id: operation, attempt_number: 1,
        browser_session_ref: current.public_id, planned_count: count, expires_at: deadline,
        created_at: now, updated_at: now,
      )
      ClientSecretAuditOutbox.record!(
        actor_context: context, client_ref: actor.public_id, operation_ref: operation, occurred_at: now,
        event_name: count.zero? ? "secret.issuance_omitted" : "secret.issuance_started",
        reason: count.zero? ? "capacity_full" : "passkey_registration", item_count: count,
      )
      ClientSecretCapacityQuery.call(client: actor, at: now)
      issuance
    end
  end
end
