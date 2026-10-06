# frozen_string_literal: true

# Base owns the only authority transition. Token freshness, transaction consumption and Auth
# continuity completion share the actor-specific ticket connection and transaction. The principal
# credential remains locked while those writes commit; no normal page needs this credential lookup.
class IdentityStepUpCeremonyFreshnessCommitter
  class << self
    public

    def call!(actor:, token:, transaction:, requirement:, raw_result: nil, result_reference: nil)
      binding = binding_for(actor, token, transaction)
      credentials = binding.fetch(2)
      payload, digest = read_result_delivery(
        transaction: transaction, raw_result: raw_result, result_reference: result_reference,
      )
      actor.class.connection_class_for_self.connected_to(role: :writing) do
        actor.with_lock do
          raise IdentityStepUpCeremonyContract::Error.new(
            "actor unavailable",
            code: "authorization_denied",
          ) unless actor.login_allowed?

          credential =
            case actor
            when Operator then credentials.lock.find_by!(external_id: transaction.verified_credential_ref)
            when Client, Visitor then credentials.lock.find_by!(public_id: transaction.verified_credential_ref)
            end
          finalize_ticket!(
            actor: actor, token: token, transaction: transaction, requirement: requirement,
            payload: payload, digest: digest, binding: binding, credential: credential,
          )
        end
      end
    end

    def read_result_delivery(transaction:, raw_result:, result_reference:)
      if result_reference.present?
        [
          BaseAuthAdmissionCoordinator.read_result_reference!(
            reference: result_reference, surface: transaction.surface,
            transaction_ref: transaction.transaction_id, expected_intent: "step_up",
          ),
          transaction.result_digest,
        ]
      else
        raise ArgumentError, "step-up result is required" unless raw_result.is_a?(String) && raw_result.present?

        [
          BaseAuthAdmissionCoordinator.read_result!(
            raw_code: raw_result, surface: transaction.surface,
            transaction_ref: transaction.transaction_id, expected_intent: "step_up",
          ),
          Valkey::AuthState::OpaqueAdmissionStore.digest_for(purpose: "step_up_result", raw_code: raw_result),
        ]
      end
    end

    private

    def finalize_ticket!(actor:, token:, transaction:, requirement:, payload:, digest:, binding:, credential:)
      return finalize_full_reauthentication_ticket!(
        actor:, token:, transaction:, requirement:, payload:, digest:, binding:, credential:,
      ) if transaction.purpose == "reauthentication"

      finalize_standard_ticket!(
        actor:, token:, transaction:, requirement:, payload:, digest:, binding:, credential:,
      )
    end

    def finalize_standard_ticket!(actor:, token:, transaction:, requirement:, payload:, digest:, binding:, credential:)
      session_model, ceremony_model, credentials = binding
      transaction.class.connection_owner.connected_to(role: :writing) do
        token.with_lock do
          session_record = session_model.lock.find_by!(step_up_ceremony_transaction_ref: transaction.transaction_id)
          transaction.with_lock do
            now = transaction.class.database_now
            unless credentials.exists?(id: credential.id)
              raise IdentityStepUpCeremonyContract::Error.new(
                "verified credential unavailable",
                code: "authorization_denied",
              )
            end

            validate_finalization!(actor, token, transaction, requirement, now)
            unless transaction.result_delivery_matches?(
              result_digest: digest, result_generation: payload.fetch("result_generation"), now: now,
            )
              raise BaseAuthAdmissionCoordinator::Denied.new(
                "step-up result generation mismatch",
                code: "return_binding_mismatch",
              )
            end

            ceremony = ceremony_model.lock.find(payload.fetch("ceremony_session_ref"))
            validate_continuity!(ceremony, transaction, now)
            unless session_owned_by?(session_record, token) && session_record.scope == transaction.required_scope
              raise IdentityStepUpCeremonyContract::Error.new(
                "session scope or owner mismatch",
                code: "session_binding_mismatch",
              )
            end

            if transaction.consumed?
              unless ceremony.completed? && token.last_step_up_at == transaction.verified_at &&
                  StepUpResolver.call(token: token, requirement: requirement, now: now).satisfied?
                raise IdentityStepUpCeremonyContract::Error.new(
                  "finalized authority no longer available",
                  code: "authorization_denied",
                )
              end
            else
              commit!(token, transaction, ceremony, requirement, now)
            end
            # Keep the same row for replay/retention; no latest-pending replacement or deletion.
            transaction
          end
        end
      end
    end

    # Full reauthentication is the one step-up purpose allowed to replace the root token. The
    # Device Session is locked before the current root row, preserving the same order used by root
    # refresh and RP issuance. The admitted transaction is consumed in the same Ticket transaction
    # as the replacement, so a failed replacement cannot leave a consumed ceremony behind.
    def finalize_full_reauthentication_ticket!(actor:, token:, transaction:, requirement:, payload:, digest:, binding:,
                                               credential:)
      session_model, ceremony_model, credentials = binding
      transaction.class.connection_owner.connected_to(role: :writing) do
        device_session = token.device_session
        raise IdentityStepUpCeremonyContract::Error.new(
          "Browser Session is missing", code: "session_expired",
        ) unless device_session

        device_session.with_lock do
          current_token = token.class.lock.find_by(id: device_session.current_refresh_token_id)
          unless current_token&.id == token.id
            raise IdentityStepUpCeremonyContract::Error.new(
              "Browser Session current root token changed", code: "session_expired",
            )
          end

          current_token.with_lock do
            previous_token = token.class.lock.find_by(public_id: transaction.session_ref)
            session_record = session_model.lock.find_by!(step_up_ceremony_transaction_ref: transaction.transaction_id)
            transaction.with_lock do
              now = transaction.class.database_now
              unless credentials.exists?(id: credential.id)
                raise IdentityStepUpCeremonyContract::Error.new(
                  "verified credential unavailable", code: "authorization_denied",
                )
              end

              if transaction.consumed?
                validate_consumed_reauthentication_finalization!(
                  actor, current_token, previous_token, transaction, requirement, now,
                )
              else
                validate_finalization!(actor, current_token, transaction, requirement, now)
              end
              unless transaction.result_delivery_matches?(
                result_digest: digest, result_generation: payload.fetch("result_generation"), now: now,
              )
                raise BaseAuthAdmissionCoordinator::Denied.new(
                  "step-up result generation mismatch", code: "return_binding_mismatch",
                )
              end

              ceremony = ceremony_model.lock.find(payload.fetch("ceremony_session_ref"))
              validate_continuity!(ceremony, transaction, now)
              session_token = transaction.consumed? ? previous_token : current_token
              unless session_token && session_owned_by?(session_record, session_token) &&
                  session_record.scope == transaction.required_scope
                raise IdentityStepUpCeremonyContract::Error.new(
                  "session scope or owner mismatch", code: "session_binding_mismatch",
                )
              end

              if transaction.consumed?
                unless ceremony.completed? && current_token.last_step_up_at == transaction.verified_at &&
                    StepUpResolver.call(token: current_token, requirement: requirement, now: now).satisfied?
                  raise IdentityStepUpCeremonyContract::Error.new(
                    "finalized authority no longer available", code: "authorization_denied",
                  )
                end
              else
                replacement = token.class.replace_current_for_reauthentication!(
                  token: current_token, authentication_event_at: transaction.verified_at,
                  established_authentication_method: established_authentication_method_for(transaction.method),
                  now: now,
                )
                current_token.revoke_step_up_authority!(now: now, except_transaction_ref: transaction.transaction_id)
                commit_step_up_event!(
                  replacement.fetch(:token), transaction, requirement,
                )
                transaction.commit_consumption!(now: now)
                ceremony.complete!(now: now)
              end
              transaction
            end
          end
        end
      end
    end

    def session_owned_by?(record, token)
      case token
      when ClientToken then record.user_token_id == token.id
      when VisitorToken then record.visitor_token_id == token.id
      when OperatorToken then record.staff_token_id == token.id
      end
    end

    # [session model, continuity model, actor-owned active credential relation]
    def binding_for(actor, token, transaction)
      case token
      when ClientToken
        unless actor.is_a?(Client) && token.user_id == actor.id && transaction.is_a?(ClientStepUpCeremonyTransaction)
          raise IdentityStepUpCeremonyContract::Error.new("APP binding mismatch", code: "session_binding_mismatch")
        end

        [ClientStepUpSession, ClientAuthCeremonySession, credential_scope(actor, transaction.method)]
      when VisitorToken
        unless actor.is_a?(Visitor) && token.visitor_id == actor.id &&
            transaction.is_a?(VisitorStepUpCeremonyTransaction)
          raise IdentityStepUpCeremonyContract::Error.new("COM binding mismatch", code: "session_binding_mismatch")
        end

        [VisitorStepUpSession, VisitorAuthCeremonySession, credential_scope(actor, transaction.method)]
      when OperatorToken
        unless actor.is_a?(Operator) && token.staff_id == actor.id &&
            transaction.is_a?(OperatorStepUpCeremonyTransaction) &&
            !token.emergency_authentication_context?
          raise IdentityStepUpCeremonyContract::Error.new("ORG binding mismatch", code: "session_binding_mismatch")
        end

        [OperatorStepUpSession, OperatorAuthCeremonySession, credential_scope(actor, transaction.method)]
      else
        raise IdentityStepUpCeremonyContract::Error.new("unsupported Base session", code: "session_binding_mismatch")
      end
    end

    def credential_scope(actor, method)
      case [actor, method]
      in [Client, "passkey"]
        actor.client_passkeys.active.where("discard_at > clock_timestamp()")
      in [Client, "email_otp"]
        actor.client_emails.effective_binding.where(user_email_status_id: AuthMethodGuard::VERIFIED_EMAIL_STATUSES)
          .where("discard_at > clock_timestamp()")
      in [Client, "totp"]
        actor.client_totp_credentials.where(user_identity_totp_credential_status_id: ClientTotpCredentialStatus::ACTIVE)
      in [Visitor, "passkey"]
        actor.visitor_passkeys.active.where("discard_at > clock_timestamp()")
      in [Visitor, "email_otp"]
        actor.visitor_emails.effective_binding.where(visitor_email_status_id: AuthMethodGuard::VISITOR_VERIFIED_EMAIL_STATUSES)
          .where("discard_at > clock_timestamp()")
      in [Operator, "passkey"]
        actor.staff_passkeys.active
      else
        raise IdentityStepUpCeremonyContract::Error.new("credential method unavailable", code: "unsupported_method")
      end
    end

    def validate_finalization!(actor, token, transaction, requirement, now)
      unless token.currently_usable?(now) && transaction.actor_ref == actor.public_id &&
          transaction.session_ref == token.public_id && %w(step_up reauthentication).include?(transaction.purpose) &&
          %w(verified consumed).include?(transaction.status) && !transaction.expired?(now: now)
        raise IdentityStepUpCeremonyContract::Error.new("step-up actor or session unavailable", code: "session_expired")
      end

      validate_requirement!(token, transaction, requirement)
      validate_evidence!(transaction, requirement, now)
    end

    # A full reauthentication replaces the root token as part of the first commit. A lost
    # completion response therefore arrives with the replacement token while the durable
    # transaction and Auth session still name the rotated predecessor. Accept that exact
    # predecessor/current-device pair only for an already-consumed transaction; the first
    # finalization continues to require the transaction's original root row.
    def validate_consumed_reauthentication_finalization!(actor, current_token, previous_token, transaction,
                                                         requirement, now)
      unless current_token.currently_usable?(now) && previous_token&.rotated_at.present? &&
          previous_token.device_session_id == current_token.device_session_id &&
          actor_matches_token?(actor, previous_token) && transaction.actor_ref == actor.public_id &&
          transaction.session_ref == previous_token.public_id && transaction.purpose == "reauthentication" &&
          transaction.status == "consumed" && !transaction.expired?(now: now)
        raise IdentityStepUpCeremonyContract::Error.new(
          "reauthentication replay binding unavailable", code: "session_expired",
        )
      end

      unless requirement.is_a?(StepUpRequirement) && requirement.step_up_required? &&
          requirement.scope == transaction.required_scope && requirement.purpose == transaction.purpose &&
          requirement.audience == transaction.audience && requirement.actor_ref == transaction.actor_ref &&
          requirement.resource_ref == transaction.resource_ref && requirement.tenant_ref == transaction.tenant_ref &&
          requirement.method_allowed?(transaction.method) && transaction.allowed_methods_array.include?(transaction.method) &&
          requirement.session_binding == current_token.public_id && requirement.token_binding == current_token.public_id
        raise IdentityStepUpCeremonyContract::Error.new("step-up requirement mismatch", code: "return_binding_mismatch")
      end

      if requirement.full_reauthentication_required? && transaction.purpose != "reauthentication"
        raise IdentityStepUpCeremonyContract::Error.new(
          "full reauthentication requirement mismatch", code: "return_binding_mismatch",
        )
      end
      validate_evidence!(transaction, requirement, now)
    end

    def actor_matches_token?(actor, token)
      case [actor, token]
      in [Client, ClientToken] then token.user_id == actor.id
      in [Visitor, VisitorToken] then token.visitor_id == actor.id
      in [Operator, OperatorToken] then token.staff_id == actor.id
      else false
      end
    end

    def validate_requirement!(token, transaction, requirement)
      unless requirement.is_a?(StepUpRequirement) && requirement.step_up_required? &&
          requirement.scope == transaction.required_scope && requirement.purpose == transaction.purpose &&
          requirement.audience == transaction.audience && requirement.require_session_binding == transaction.require_session_binding &&
          requirement.session_binding == token.public_id && requirement.token_binding == token.public_id &&
          requirement.actor_ref == transaction.actor_ref && requirement.resource_ref == transaction.resource_ref &&
          requirement.tenant_ref == transaction.tenant_ref &&
          requirement.method_allowed?(transaction.method) &&
          transaction.allowed_methods_array.include?(transaction.method)
        raise IdentityStepUpCeremonyContract::Error.new("step-up requirement mismatch", code: "return_binding_mismatch")
      end

      return unless requirement.full_reauthentication_required? && transaction.purpose != "reauthentication"

      raise IdentityStepUpCeremonyContract::Error.new(
        "full reauthentication requirement mismatch",
        code: "return_binding_mismatch",
      )

    end

    def validate_evidence!(transaction, requirement, now)
      unless [true, false].include?(transaction.user_verified) &&
          transaction.verified_credential_ref.is_a?(String) && transaction.verified_credential_ref.present? &&
          transaction.phishing_resistant == (transaction.method == "passkey") &&
          (!requirement.phishing_resistant_required? || transaction.phishing_resistant) &&
          (!requirement.user_verification_required? || transaction.user_verified) &&
          transaction.verified_at && transaction.verified_at <= now && transaction.verified_at + requirement.ttl > now
        raise IdentityStepUpCeremonyContract::Error.new("step-up evidence unavailable", code: "invalid_evidence")
      end
    end

    def validate_continuity!(ceremony, transaction, now)
      unless ceremony.admitted? && ceremony.admission_purpose == "step_up_handoff" &&
          ceremony.step_up_ceremony_transaction_ref == transaction.transaction_id &&
          !ceremony.revoked_at && !ceremony.cancelled_at && ceremony.expires_at > now &&
          (ceremony.active?(now: now) || (transaction.consumed? && ceremony.completed?))
        raise IdentityStepUpCeremonyContract::Error.new("Auth continuity unavailable", code: "return_binding_mismatch")
      end
    end

    def commit!(token, transaction, ceremony, requirement, now)
      commit_step_up_event!(token, transaction, requirement)
      transaction.commit_consumption!(now: now)
      ceremony.complete!(now: now)
    end

    def commit_step_up_event!(token, transaction, requirement)
      token.update!(
        last_step_up_at: transaction.verified_at, last_step_up_scope: transaction.required_scope,
        # @deprecated `last_step_up_aal` remains a label and is not read for authorization.
        last_step_up_aal: transaction.aal, last_step_up_method: transaction.method,
        last_step_up_phishing_resistant: transaction.phishing_resistant,
        last_step_up_user_verified: transaction.user_verified,
        last_step_up_credential_ref: transaction.verified_credential_ref,
        # Current policy may strengthen the admitted snapshot at acceptance. Persist the effective
        # event so a later resolver cannot bypass the policy that authorized this mutation.
        last_step_up_full_reauthentication: transaction.full_reauthentication_required ||
          requirement.full_reauthentication_required?,
        last_step_up_resource_ref: transaction.resource_ref,
        last_step_up_tenant_ref: transaction.tenant_ref,
        last_step_up_purpose: transaction.purpose, last_step_up_audience: requirement.audience,
        last_step_up_session_public_id: token.public_id,
      )
    end

    def established_authentication_method_for(method)
      AuthenticationBase::ESTABLISHED_AUTHENTICATION_METHOD_MAP.fetch(method.to_s) do
        raise IdentityStepUpCeremonyContract::Error.new(
          "reauthentication method unavailable",
          code: "unsupported_method",
        )
      end
    end
  end
end
