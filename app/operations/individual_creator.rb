# typed: false
# frozen_string_literal: true

# Creates a com Individual with the authenticated Visitor as its first owner.
class IndividualCreator
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

  def initialize(actor:, owner:, visitor_identity:, moniker: nil, title:)
    @actor = actor
    @owner = owner
    @visitor_identity = visitor_identity
    @moniker = moniker
    @title = title
  end

  def call
    validate_actor!
    validate_identity!(owner:)

    ComZenithRecord.transaction do
      VisitorAuthorityLock.acquire_for!(visitor_id: owner.id)
      locked_owner = Visitor.lock.find(owner.id)
      validate_owner_active!(locked_owner)
      locked_identity = VisitorIdentity.lock.find_by(id: visitor_identity.id)
      validate_identity!(identity: locked_identity, owner: locked_owner)
      raise QuotaExceeded, "visitor #{owner.id} owns the maximum number of personas" if owned_count >= LIMIT

      individual = Individual.create!(
        visitor_identity: locked_identity,
        moniker: moniker,
        title: title,
      )
      IndividualOwnership.create!(
        individual:,
        visitor: locked_owner,
        ownership_revision: 0,
      )
      individual
    end
  end

  private

  attr_reader :actor, :owner, :visitor_identity, :moniker, :title

  def validate_actor!
    return if actor.instance_of?(Visitor) && owner.instance_of?(Visitor) && actor.id == owner.id

    raise InvalidActor, "the authenticated visitor must become the owner"
  end

  def validate_identity!(identity: visitor_identity, owner:)
    valid_identity =
      identity.instance_of?(VisitorIdentity) &&
      identity.source_record_id == owner.id &&
      identity.status_id == VisitorIdentityState::ACTIVE
    return if valid_identity

    raise IdentityMismatch, "visitor identity is not an active binding for the owner"
  end

  def validate_owner_active!(locked_owner)
    return if locked_owner.status_id == VisitorStatus::ACTIVE &&
      locked_owner.login_allowed? &&
      locked_owner.access_enabled?

    raise InactiveOwner, "the owner is not allowed to create an individual"
  end

  def owned_count
    IndividualOwnership.where(visitor_id: owner.id).count
  end
end
