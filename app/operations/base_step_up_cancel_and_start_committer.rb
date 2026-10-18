# frozen_string_literal: true

# Cancels a still-live step-up ceremony and starts its replacement while the
# actor, Base token, ceremony parent and linked Auth continuity follow the same
# lock order as ordinary step-up issuance. A consumed/finalized parent is never
# reopened by this operation.
class BaseStepUpCancelAndStartCommitter
  class << self
    public

    def call!(actor:, token:, previous_transaction:, requirement:, return_to:, base_browser_nonce:, base_token:)
      actor.class.connection_class_for_self.connected_to(role: :writing) do
        actor.with_lock do
          previous_transaction.class.connection_owner.connected_to(role: :writing) do
            previous_transaction.class.connection_owner.transaction do
              device_session = token.device_session_record!
              device_session.with_lock do
                token.with_lock do
                  validate_browser_context!(
                    actor:, token:, previous_transaction:, base_browser_nonce:, base_token:,
                  )
                  canceled = IdentityStepUpCeremonyCancellationCommitter.call!(
                    actor:, token:, transaction: previous_transaction,
                  )
                  unless canceled
                    if previous_transaction.consumed?
                      return BaseAuthAdmissionCoordinator::TerminalOutcome.new(transaction: previous_transaction)
                    end

                    raise BaseAuthAdmissionCoordinator::Denied.new(
                      "step-up transaction is unavailable", code: "transaction_unavailable",
                    )
                  end

                  BaseStepUpAdmissionIssuer.call!(
                    actor:, token:, requirement:, return_to:, base_browser_nonce:, base_token:,
                  )
                end
              end
            end
          end
        end
      end
    rescue IdentityStepUpCeremonyContract::Error => e
      raise BaseAuthAdmissionCoordinator::Denied.new(e.message, code: e.code)
    end

    private

    def validate_browser_context!(actor:, token:, previous_transaction:, base_browser_nonce:, base_token:)
      unless base_token.equal?(token)
        raise BaseAuthAdmissionCoordinator::Denied.new(
          "Base token binding is invalid", code: "session_binding_mismatch",
        )
      end

      previous_transaction.reload
      if previous_transaction.consumed?
        BaseAuthAdmissionCoordinator.validate_result_browser_binding!(
          transaction: previous_transaction, surface: previous_transaction.surface, base_browser_nonce:, base_token:,
        )
      else
        BaseStepUpAdmissionIssuer.conflict_binding_for_form!(
          actor:, token:, transaction: previous_transaction, base_browser_nonce:, base_token:,
        )
      end
    end
  end
end
