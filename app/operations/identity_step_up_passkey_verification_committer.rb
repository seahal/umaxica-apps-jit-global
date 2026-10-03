# frozen_string_literal: true

# Challenge consumption commits before signature verification. Principal writes finish before
# recording ticket evidence; Base must still recheck this credential when finalizing authority.
class IdentityStepUpPasskeyVerificationCommitter
  class << self
    public

    def call!(actor:, transaction:, session_record:, config:, reference:, credential_params:)
      validate_binding!(actor, transaction, session_record)
      challenge = session_record.consume_bound_passkey_challenge!(
        transaction: transaction, reference: reference, rp_id: config.rp_id, origin: config.origin,
      )
      unless credential_params.is_a?(Hash) && credential_params["id"].is_a?(String) &&
          credential_params["id"].present? && credential_params["id"].exclude?("\0")
        raise Webauthn::AssertionVerifier::VerificationError, "credential identifier missing"
      end

      context = nil
      credential = nil
      actor.class.connection_class_for_self.connected_to(role: :writing) do
        actor.with_lock do
          raise IdentityStepUpCeremonyContract::Error, "actor unavailable" unless actor.login_allowed?

          credential = credential_scope(actor).where("discard_at > clock_timestamp()")
            .lock.find_by!(webauthn_id: credential_params.fetch("id"))

          context = Webauthn::AssertionVerifier.verify!(
            credential_params: credential_params, challenge: challenge, config: config,
            public_key: credential.public_key, sign_count: credential.sign_count,
            purpose: :ordinary_step_up,
          )
          credential.update!(sign_count: context.sign_count, uv_verified_at: context.verified_at)
        end
      end
      transaction.record_verification!(
        method: "passkey", aal: "aal1", phishing_resistant: true,
        verified_at: context.verified_at, verified_credential_ref: credential.public_id,
      )
    end

    private

    def validate_binding!(actor, transaction, session_record)
      token =
        case actor
        when Client
          unless transaction.is_a?(ClientStepUpCeremonyTransaction) && session_record.is_a?(ClientStepUpSession)
            raise IdentityStepUpCeremonyContract::Error, "step-up surface mismatch"
          end

          session_record.user_token
        when Visitor
          unless transaction.is_a?(VisitorStepUpCeremonyTransaction) && session_record.is_a?(VisitorStepUpSession)
            raise IdentityStepUpCeremonyContract::Error, "step-up surface mismatch"
          end

          session_record.visitor_token
        when Operator
          unless transaction.is_a?(OperatorStepUpCeremonyTransaction) && session_record.is_a?(OperatorStepUpSession)
            raise IdentityStepUpCeremonyContract::Error, "step-up surface mismatch"
          end

          session_record.staff_token
        else
          raise IdentityStepUpCeremonyContract::Error, "step-up actor type mismatch"
        end
      unless transaction.actor_ref == actor.public_id && transaction.session_ref == token.public_id &&
          token_owned_by?(actor, token) && token.currently_usable?
        raise IdentityStepUpCeremonyContract::Error, "step-up actor or session mismatch"
      end
    end

    def token_owned_by?(actor, token)
      case actor
      when Client then token.user_id == actor.id
      when Visitor then token.visitor_id == actor.id
      when Operator then token.staff_id == actor.id && !token.emergency_authentication_context?
      end
    end

    def credential_scope(actor)
      case actor
      when Client then actor.client_passkeys.active
      when Visitor then actor.visitor_passkeys.active
      when Operator then actor.staff_passkeys.active
      end
    end
  end
end
