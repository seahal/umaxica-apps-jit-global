# frozen_string_literal: true

# Base confirms a first email address itself, so its bootstrap is consumed here instead of through
# an Auth result. The transaction goes from pending to consumed and writes no Step-Up freshness: the
# protected operation still needs an ordinary verification with the address just registered.
class IdentityEmailBootstrapCommitter
  METHOD = "email_otp"

  class << self
    public

    def call!(actor:, token:, transaction:, credential:)
      validate_binding!(actor, token, transaction, credential)
      Client.connection_class_for_self.connected_to(role: :writing) do
        actor.with_lock do
          refuse!("bootstrap actor unavailable", "authorization_denied") unless actor.login_allowed?

          AppTicketRecord.connected_to(role: :writing) do
            token.with_lock do
              ClientStepUpSession.lock.find_by!(
                user_token_id: token.id, step_up_ceremony_transaction_ref: transaction.transaction_id,
              )
              transaction.with_lock do
                now = ClientStepUpCeremonyTransaction.database_now
                validate_ticket!(actor, token, transaction, now)
                transaction.commit_registration_consumption!(
                  now: now, method: METHOD, registered_credential_ref: credential.public_id,
                )
              end
            end
          end
        end
      end
      transaction
    rescue ActiveRecord::RecordNotFound
      refuse!("bootstrap session unavailable", "session_binding_mismatch")
    end

    private

    def refuse!(message, code)
      raise IdentityStepUpCeremonyContract::Error.new(message, code: code)
    end

    def validate_binding!(actor, token, transaction, credential)
      return if actor.is_a?(Client) && token.is_a?(ClientToken) &&
        transaction.is_a?(ClientStepUpCeremonyTransaction) && credential.is_a?(ClientEmail) &&
        token.user_id == actor.id && credential.user_id == actor.id &&
        credential.user_email_status_id == ClientEmailStatus::VERIFIED

      refuse!("email bootstrap binding mismatch", "session_binding_mismatch")
    end

    def validate_ticket!(actor, token, transaction, now)
      refuse!("bootstrap session unavailable", "session_expired") unless token.currently_usable?(now)
      unless transaction.actor_ref == actor.public_id && transaction.session_ref == token.public_id
        refuse!("email bootstrap binding mismatch", "session_binding_mismatch")
      end
      unless transaction.purpose == "bootstrap" && transaction.allowed_methods_array == [METHOD]
        refuse!("email bootstrap method unavailable", "unsupported_method")
      end
      return if transaction.status == StepUpCeremonyTransactionable::STATUS_PENDING && !transaction.expired?(now: now)

      refuse!(
        "email bootstrap is not open",
        transaction.unavailable_refusal_code(expected_purposes: ["bootstrap"], now: now),
      )
    end
  end
end
