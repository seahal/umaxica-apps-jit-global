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
      principal_class(actor).connection_class_for_self.connected_to(role: :writing) do
        actor.with_lock do
          refuse!("bootstrap actor unavailable", "authorization_denied") unless actor.login_allowed?

          ticket_record_class(actor).connected_to(role: :writing) do
            token.with_lock do
              step_up_session_class(actor).lock.find_by!(
                session_foreign_key(actor) => token.id,
                :step_up_ceremony_transaction_ref => transaction.transaction_id,
              )
              transaction.with_lock do
                now = transaction.class.database_now
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
      case actor
      when Client
        return if token.is_a?(ClientToken) && transaction.is_a?(ClientStepUpCeremonyTransaction) &&
          credential.is_a?(ClientEmail) && token.user_id == actor.id && credential.user_id == actor.id &&
          credential.user_email_status_id == ClientEmailStatus::VERIFIED
      when Visitor
        return if token.is_a?(VisitorToken) && transaction.is_a?(VisitorStepUpCeremonyTransaction) &&
          credential.is_a?(VisitorEmail) && token.visitor_id == actor.id && credential.visitor_id == actor.id &&
          credential.visitor_email_status_id == VisitorEmailStatus::VERIFIED
      when Operator
        return if token.is_a?(OperatorToken) && transaction.is_a?(OperatorStepUpCeremonyTransaction) &&
          credential.is_a?(OperatorEmail) && token.staff_id == actor.id && credential.staff_id == actor.id &&
          credential.staff_email_status_id == OperatorEmailStatus::VERIFIED
      end

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

    def principal_class(actor)
      case actor
      when Client then Client
      when Visitor then Visitor
      when Operator then Operator
      else refuse!("email bootstrap actor type mismatch", "session_binding_mismatch")
      end
    end

    def ticket_record_class(actor)
      case actor
      when Client then AppTicketRecord
      when Visitor then ComTicketRecord
      when Operator then OrgTicketRecord
      else refuse!("email bootstrap actor type mismatch", "session_binding_mismatch")
      end
    end

    def step_up_session_class(actor)
      case actor
      when Client then ClientStepUpSession
      when Visitor then VisitorStepUpSession
      when Operator then OperatorStepUpSession
      else refuse!("email bootstrap actor type mismatch", "session_binding_mismatch")
      end
    end

    def session_foreign_key(actor)
      case actor
      when Client then :user_token_id
      when Visitor then :visitor_token_id
      when Operator then :staff_token_id
      else refuse!("email bootstrap actor type mismatch", "session_binding_mismatch")
      end
    end
  end
end
