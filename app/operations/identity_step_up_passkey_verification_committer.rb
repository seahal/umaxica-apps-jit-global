# frozen_string_literal: true

# Challenge consumption commits before signature verification. Principal writes finish before
# recording ticket evidence; Base must still recheck this credential when finalizing authority.
class IdentityStepUpPasskeyVerificationCommitter
  class << self
    public

    def call!(actor:, transaction:, session_record:, config:, reference:, credential_params:)
      with_current_binding!(actor, transaction, session_record)
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

          credential = credential_scope(actor).lock.find_by!(webauthn_id: credential_params.fetch("id"))

          context = Webauthn::AssertionVerifier.verify!(
            credential_params: credential_params, challenge: challenge, config: config,
            public_key: credential.public_key, sign_count: credential.sign_count,
            purpose: :ordinary_step_up,
          )
          credential.update!(sign_count: context.sign_count, uv_verified_at: context.verified_at)
        end
      end
      actor.class.connection_class_for_self.connected_to(role: :writing) do
        actor.with_lock do
          unless actor.login_allowed? && credential_scope(actor).lock.exists?(id: credential.id)
            raise IdentityStepUpCeremonyContract::Error, "actor or Passkey unavailable"
          end

          with_current_binding!(actor, transaction, session_record) do
            transaction.record_verification!(
              method: "passkey", aal: "aal1", phishing_resistant: true, user_verified: context.user_verified,
              verified_at: context.verified_at, verified_credential_ref: credential_reference(credential),
            )
          end
        end
      end
    end

    private

    def with_current_binding!(actor, transaction, session_record)
      token =
        case actor
        when Client
          unless transaction.is_a?(ClientStepUpCeremonyTransaction) && session_record.is_a?(ClientStepUpSession)
            raise IdentityStepUpCeremonyContract::Error, "step-up surface mismatch"
          end

          ClientToken.find(session_record.user_token_id)
        when Operator
          unless transaction.is_a?(OperatorStepUpCeremonyTransaction) && session_record.is_a?(OperatorStepUpSession)
            raise IdentityStepUpCeremonyContract::Error, "step-up surface mismatch"
          end

          OperatorToken.find(session_record.staff_token_id)
        else
          raise IdentityStepUpCeremonyContract::Error, "step-up actor type mismatch"
        end
      token.class.connection_class_for_self.connected_to(role: :writing) do
        device = token.device_session_record!
        device.with_lock do
          token.with_lock do
            transaction.with_lock do
              session_record.with_lock do
                validate_current_binding!(actor, token, device, transaction, session_record)
                if block_given?
                  validate_pending_binding!(transaction, session_record)
                  yield
                end
              end
            end
          end
        end
      end
    end

    def validate_current_binding!(actor, token, device, transaction, record)
      now = transaction.class.database_now
      device_owner_matches =
        case [actor, device]
        in [Client, ClientDeviceSession] then device.user_id == actor.id
        in [Operator, OperatorDeviceSession] then device.staff_id == actor.id
        else false
        end
      record_token_matches =
        case record
        when ClientStepUpSession then record.user_token_id == token.id
        when OperatorStepUpSession then record.staff_token_id == token.id
        end
      unless device_owner_matches && device.usable? && token.device_session_id == device.id &&
          device.current_refresh_token_id == token.id && token_owned_by?(actor, token) && token.active_status?(now) &&
          record_token_matches && record.step_up_ceremony_transaction_ref == transaction.transaction_id &&
          transaction.actor_ref == actor.public_id && transaction.session_ref == token.public_id
        raise IdentityStepUpCeremonyContract::Error, "step-up actor or session mismatch"
      end
    end

    def validate_pending_binding!(transaction, record)
      now = transaction.class.database_now
      return if record.status == "PENDING" && record.discard_at > now &&
        %w(step_up reauthentication).include?(transaction.purpose) &&
        transaction.allowed_methods_array.include?("passkey") && transaction.status == "pending" &&
        !transaction.expired?(now: now)

      raise IdentityStepUpCeremonyContract::Error, "step-up ceremony unavailable"
    end

    def token_owned_by?(actor, token)
      case actor
      when Client then token.user_id == actor.id
      when Operator then token.staff_id == actor.id && !token.standby_authentication_context?
      end
    end

    def credential_scope(actor)
      case actor
      when Client then actor.client_passkeys.active.where("discard_at > clock_timestamp()")
      when Operator then actor.staff_passkeys.active
      end
    end

    def credential_reference(credential)
      case credential
      when ClientPasskey then credential.public_id
      when OperatorPasskey then credential.external_id
      else
        raise IdentityStepUpCeremonyContract::Error, "unsupported credential reference"
      end
    end
  end
end
