# frozen_string_literal: true

# Commits a Visa session-limit Cancel without reversing the principal-first lock order.
# Valkey delivery is prepared before either database row is locked; its handoff is
# not usable until the OP transaction binds it together with the resolution transition.
class SessionLimitOidcCancellationCommitter
  MAX_BINDING_CONFLICT_RETRIES = 1

  class << self
    public

    def call!(actor:, resolution:, transaction:, challenge:, browser_binding:, store: nil)
      new(
        actor:, resolution:, transaction:, challenge:, browser_binding:, store:,
      ).call!
    end
  end

  public

  def initialize(actor:, resolution:, transaction:, challenge:, browser_binding:, store:)
    @actor = actor
    @resolution = resolution
    @transaction = transaction
    @challenge = challenge
    @browser_binding = browser_binding
    @store = store
  end

  def call!
    validate_binding!
    retries = 0

    loop do
      begin
        preparation =
          if store
            BaseAuthAdmissionCoordinator.prepare_cancellation!(transaction:, store:)
          else
            BaseAuthAdmissionCoordinator.prepare_cancellation!(transaction:)
          end
        issuance = commit_with_actor_lock!(preparation)
        return issuance if issuance

        return false
      rescue BaseAuthAdmissionCoordinator::Denied => e
        raise unless e.code == "transaction_conflict" && retries < MAX_BINDING_CONFLICT_RETRIES

        retries += 1
        transaction.reload
      end
    end
  end

  private

  attr_reader :actor, :resolution, :transaction, :challenge, :browser_binding, :store

  def commit_with_actor_lock!(preparation)
    result =
      actor.class.connection_class_for_self.connected_to(role: :writing) do
        actor.with_lock do
          raise BaseAuthAdmissionCoordinator::Denied.new(
            "session-limit actor changed", code: "invalid_admission",
          ) unless
            actor.public_id == resolution.actor_ref

          owner = transaction.class.connection_owner
          owner.connected_to(role: :writing) do
            owner.transaction do
              issuance = BaseAuthAdmissionCoordinator.commit_cancellation!(transaction:, preparation:)
              unless cancel_resolution_records!
                raise ActiveRecord::Rollback
              end

              issuance
            end
          end
        end
      end
    result || false
  end

  def cancel_resolution_records!
    flow_class = resolution.class.resolution_sign_in_flow_class
    resolution.cancel!(
      actor: actor, challenge: challenge,
      browser_binding_digest: resolution.class.digest_challenge(browser_binding),
    )
    flow = flow_class.find(resolution.sign_in_flow_id)
    flow.cancel_sign_in! unless flow.sign_in_completed? || flow.sign_in_expired? ||
      flow.sign_in_cancelled? || flow.sign_in_halted?
    true
  rescue FlowInvalidTransition, ActiveRecord::RecordNotFound
    false
  end

  def validate_binding!
    surface =
      case [actor, resolution, transaction]
      in [Client, ClientSessionLimitResolutionTransaction, ClientOidcAuthorizationTransaction] then "app"
      in [Operator, OperatorSessionLimitResolutionTransaction, OperatorOidcAuthorizationTransaction] then "org"
      else
        raise ArgumentError, "session-limit cancellation records belong to different realms"
      end

    valid = transaction.surface == surface && transaction.actor_ref == actor.public_id &&
      resolution.actor_ref == actor.public_id && resolution.oidc_authorization_transaction_id == transaction.id &&
      challenge.is_a?(String) && challenge.present? && browser_binding.is_a?(String) && browser_binding.present?
    return if valid

    raise ArgumentError, "session-limit cancellation binding is invalid"
  end
end
