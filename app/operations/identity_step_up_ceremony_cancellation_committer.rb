# frozen_string_literal: true

# Cancellation and Base finalization take the same ticket locks. The concrete transaction is
# retained as a terminal record; its challenges, jobs and results cannot restore authority.
class IdentityStepUpCeremonyCancellationCommitter
  class << self
    public

    def call!(actor:, token:, transaction:)
      session_model, ceremony_model = binding_for(actor, token, transaction)
      actor.class.connection_class_for_self.connected_to(role: :writing) do
        actor.with_lock do
          transaction.class.connection_owner.connected_to(role: :writing) do
            token.with_lock do
              unless token.currently_usable? && transaction.actor_ref == actor.public_id &&
                  transaction.session_ref == token.public_id
                raise IdentityStepUpCeremonyContract::Error, "step-up cancellation binding mismatch"
              end

              record = session_model.lock.find_by!(step_up_ceremony_transaction_ref: transaction.transaction_id)
              unless owned_record?(record, token)
                raise IdentityStepUpCeremonyContract::Error, "step-up cancellation session mismatch"
              end

              transaction.with_lock do
                now = transaction.class.database_now
                return true if transaction.status == "canceled"
                return false unless %w(pending verified).include?(transaction.status)

                if transaction.expired?(now: now)
                  transaction.update!(status: "expired")
                  return false
                end

                transaction.update!(status: "canceled", canceled_at: now)
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
          raise IdentityStepUpCeremonyContract::Error, "step-up cancellation surface mismatch"
        end

        [OperatorStepUpSession, OperatorAuthCeremonySession]
      else
        raise IdentityStepUpCeremonyContract::Error, "step-up cancellation surface mismatch"
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
