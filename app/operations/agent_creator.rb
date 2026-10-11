# typed: false
# frozen_string_literal: true

# Creates an org Agent with the authenticated Operator as its first owner.
class AgentCreator
  class InvalidActor < StandardError; end

  class InactiveOwner < StandardError; end

  class IdentityMismatch < StandardError; end

  class QuotaExceeded < StandardError; end

  LIMIT = Acme::QuotaLimits::ACCOUNT_LIMIT

  def self.call(...)
    new(...).call
  end
  public_class_method :call

  public

  def initialize(actor:, owner:, operator_identity:, moniker: nil, title:)
    @actor = actor
    @owner = owner
    @operator_identity = operator_identity
    @moniker = moniker
    @title = title
  end

  def call
    validate_actor!
    validate_identity!(owner:)

    OrgZenithRecord.transaction do
      OperatorAuthorityLock.acquire_for!(operator_id: owner.id)
      locked_owner = Operator.lock.find(owner.id)
      validate_owner_active!(locked_owner)
      locked_identity = OperatorIdentity.lock.find_by(id: operator_identity.id)
      validate_identity!(identity: locked_identity, owner: locked_owner)
      raise QuotaExceeded, "operator #{owner.id} owns the maximum number of personas" if owned_count >= LIMIT

      agent = Agent.create!(
        operator_identity: locked_identity,
        moniker: moniker,
        title: title,
      )
      AgentOwnership.create!(agent:, operator: locked_owner, ownership_revision: 0)
      agent
    end
  end

  private

  attr_reader :actor, :owner, :operator_identity, :moniker, :title

  def validate_actor!
    return if actor.instance_of?(Operator) && owner.instance_of?(Operator) && actor.id == owner.id

    raise InvalidActor, "the authenticated operator must become the owner"
  end

  def validate_identity!(identity: operator_identity, owner:)
    valid_identity =
      identity.instance_of?(OperatorIdentity) &&
      identity.source_record_id == owner.id &&
      identity.status_id == OperatorIdentityState::ACTIVE
    return if valid_identity

    raise IdentityMismatch, "operator identity is not an active binding for the owner"
  end

  def validate_owner_active!(locked_owner)
    return if locked_owner.status_id == OperatorStatus::ACTIVE &&
      locked_owner.login_allowed? &&
      locked_owner.access_enabled?

    raise InactiveOwner, "the owner is not allowed to create an agent"
  end

  def owned_count
    AgentOwnership.where(operator_id: owner.id).count
  end
end
