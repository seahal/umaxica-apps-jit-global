# frozen_string_literal: true

# Cancels a still-live step-up ceremony and starts its replacement while the
# actor, Base token, ceremony parent and linked Auth continuity follow the same
# lock order as ordinary step-up issuance. A consumed/finalized parent is never
# reopened by this operation.
class BaseStepUpCancelAndStartCommitter
  public

  def self.call!(actor:, token:, previous_transaction:, requirement:, return_to:, base_browser_nonce:, base_token:)
    unless previous_transaction.status.in?(%w(pending verified))
      raise BaseAuthAdmissionCoordinator::Denied.new(
        "step-up transaction is already terminal", code: "authorization_denied",
      )
    end

    now = previous_transaction.class.database_now
    if previous_transaction.expired?(now: now)
      raise BaseAuthAdmissionCoordinator::Denied.new("step-up transaction expired", code: "expired_admission")
    end

    actor.class.connection_class_for_self.connected_to(role: :writing) do
      actor.with_lock do
        previous_transaction.class.connection_owner.connected_to(role: :writing) do
          previous_transaction.class.connection_owner.transaction do
            token.with_lock do
              IdentityStepUpCeremonyCancellationCommitter.call!(
                actor:, token:, transaction: previous_transaction,
              )

              BaseStepUpAdmissionIssuer.call!(
                actor:, token:, requirement:, return_to:, base_browser_nonce:, base_token:,
              )
            end
          end
        end
      end
    end
  rescue IdentityStepUpCeremonyContract::Error => e
    raise BaseAuthAdmissionCoordinator::Denied.new(e.message, code: e.code)
  end
end
