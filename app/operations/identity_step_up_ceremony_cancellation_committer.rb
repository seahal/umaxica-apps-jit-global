# frozen_string_literal: true

# Cancellation and Base finalization take the same ticket locks. The concrete transaction is
# retained as a terminal record; its challenges, jobs and results cannot restore authority.
class IdentityStepUpCeremonyCancellationCommitter
  class << self
    public

    def call!(actor:, token:, transaction:, cancellation_handoff_digest: nil)
      session_model, ceremony_model = binding_for(actor, token, transaction)
      actor.class.connection_class_for_self.connected_to(role: :writing) do
        actor.with_lock do
          transaction.class.connection_owner.connected_to(role: :writing) do
            token.with_lock do
              unless transaction.actor_ref == actor.public_id &&
                  transaction.session_ref == token.public_id
                raise IdentityStepUpCeremonyContract::Error.new(
                  "step-up cancellation binding mismatch",
                  code: "session_binding_mismatch",
                )
              end

              record = session_model.lock.find_by!(step_up_ceremony_transaction_ref: transaction.transaction_id)
              unless owned_record?(record, token)
                raise IdentityStepUpCeremonyContract::Error.new(
                  "step-up cancellation session mismatch",
                  code: "session_binding_mismatch",
                )
              end

              transaction.with_lock do
                now = transaction.class.database_now
                unless token.currently_usable?(now)
                  raise IdentityStepUpCeremonyContract::Error.new(
                    "step-up cancellation session unavailable",
                    code: "session_expired",
                  )
                end

                return true if transaction.status == "canceled"
                return false unless %w(pending verified).include?(transaction.status)

                if transaction.expired?(now: now)
                  transaction.commit_expiry!
                  return false
                end

                transaction.commit_cancellation!(now: now, cancellation_handoff_digest: cancellation_handoff_digest)
                ceremonies = ceremony_model.where(step_up_ceremony_transaction_ref: transaction.transaction_id)
                ceremonies.order(:id).lock.each do |sid|
                  sid.cancel!(now: now) if sid.active?(now: now) && sid.admitted?
                end
                true
              end
            end
          end
        end
      end
    end

    private

    def binding_for(actor, token, transaction)
      case [actor, token, transaction]
      in [Client, ClientToken, ClientStepUpCeremonyTransaction] if token.user_id == actor.id
        [ClientStepUpSession, ClientAuthCeremonySession]
      in [Visitor, VisitorToken, VisitorStepUpCeremonyTransaction] if token.visitor_id == actor.id
        [VisitorStepUpSession, VisitorAuthCeremonySession]
      in [Operator, OperatorToken, OperatorStepUpCeremonyTransaction]
        unless token.staff_id == actor.id && !token.emergency_authentication_context?
          raise IdentityStepUpCeremonyContract::Error.new(
            "step-up cancellation surface mismatch",
            code: "session_binding_mismatch",
          )
        end

        [OperatorStepUpSession, OperatorAuthCeremonySession]
      else
        raise IdentityStepUpCeremonyContract::Error.new(
          "step-up cancellation surface mismatch",
          code: "session_binding_mismatch",
        )
      end
    end

    def owned_record?(record, token)
      case record
      when ClientStepUpSession then record.user_token_id == token.id
      when VisitorStepUpSession then record.visitor_token_id == token.id
      when OperatorStepUpSession then record.staff_token_id == token.id
      end
    end
  end
end
