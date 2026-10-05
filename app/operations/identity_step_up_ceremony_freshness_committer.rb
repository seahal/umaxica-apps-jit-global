# frozen_string_literal: true

# Base owns the only authority transition. Token freshness, transaction consumption and Auth
# continuity completion share the actor-specific ticket connection and transaction. The principal
# credential remains locked while those writes commit; no normal page needs this credential lookup.
class IdentityStepUpCeremonyFreshnessCommitter
  class << self
    public

    def call!(actor:, token:, transaction:, requirement:, raw_result:)
      binding = binding_for(actor, token, transaction)
      credentials = binding.fetch(2)
      payload = BaseAuthAdmissionCoordinator.read_result!(
        raw_code: raw_result, surface: transaction.surface,
        transaction_ref: transaction.transaction_id, expected_intent: "step_up",
      )
      digest = Valkey::AuthState::OpaqueAdmissionStore.digest_for(purpose: "step_up_result", raw_code: raw_result)
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

    private

    def finalize_ticket!(actor:, token:, transaction:, requirement:, payload:, digest:, binding:, credential:)
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
        actor.client_emails.where(user_email_status_id: AuthMethodGuard::VERIFIED_EMAIL_STATUSES)
          .where("discard_at > clock_timestamp()")
      in [Client, "totp"]
        actor.client_totp_credentials.where(user_identity_totp_credential_status_id: ClientTotpCredentialStatus::ACTIVE)
      in [Visitor, "passkey"]
        actor.visitor_passkeys.active.where("discard_at > clock_timestamp()")
      in [Visitor, "email_otp"]
        actor.visitor_emails.where(visitor_email_status_id: AuthMethodGuard::VISITOR_VERIFIED_EMAIL_STATUSES)
          .where("discard_at > clock_timestamp()")
      in [Operator, "passkey"]
        actor.staff_passkeys.active
      else
        raise IdentityStepUpCeremonyContract::Error.new("credential method unavailable", code: "unsupported_method")
      end
    end

    def validate_finalization!(actor, token, transaction, requirement, now)
      unless token.currently_usable?(now) && transaction.actor_ref == actor.public_id &&
          transaction.session_ref == token.public_id && transaction.purpose == "step_up" &&
          %w(verified consumed).include?(transaction.status) && !transaction.expired?(now: now)
        raise IdentityStepUpCeremonyContract::Error.new("step-up actor or session unavailable", code: "session_expired")
      end

      validate_requirement!(token, transaction, requirement)
      validate_evidence!(transaction, requirement, now)
    end

    def validate_requirement!(token, transaction, requirement)
      unless requirement.is_a?(StepUpRequirement) && requirement.step_up_required? &&
          requirement.scope == transaction.required_scope && requirement.purpose == transaction.purpose &&
          requirement.audience == "step_up:#{transaction.surface}" && requirement.require_session_binding &&
          requirement.session_binding == token.public_id && requirement.token_binding == token.public_id &&
          (requirement.required_aal&.to_s || "none") == transaction.required_aal &&
          requirement.phishing_resistant_required? == transaction.phishing_resistant_required &&
          requirement.method_allowed?(transaction.method) &&
          transaction.allowed_methods_array.include?(transaction.method)
        raise IdentityStepUpCeremonyContract::Error.new("step-up requirement mismatch", code: "return_binding_mismatch")
      end
    end

    def validate_evidence!(transaction, requirement, now)
      expected_aal = StepUpCeremonyTransactionable::METHOD_AALS.fetch(transaction.method)
      unless transaction.phishing_resistant == (transaction.method == "passkey") && transaction.aal == expected_aal &&
          (!requirement.phishing_resistant_required? || transaction.phishing_resistant) &&
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
      token.update!(
        last_step_up_at: transaction.verified_at, last_step_up_scope: transaction.required_scope,
        last_step_up_aal: transaction.aal, last_step_up_method: transaction.method,
        last_step_up_phishing_resistant: transaction.phishing_resistant,
        last_step_up_purpose: transaction.purpose, last_step_up_audience: requirement.audience,
        last_step_up_session_public_id: token.public_id,
      )
      transaction.commit_consumption!(now: now)
      ceremony.complete!(now: now)
    end
  end
end
