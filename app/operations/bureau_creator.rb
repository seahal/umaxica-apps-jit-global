# typed: false
# frozen_string_literal: true

# Creates an org Bureau with the authenticated Operator as its first owner.
class BureauCreator
  class InvalidActor < StandardError; end

  class InactiveOwner < StandardError; end

  class QuotaExceeded < StandardError; end

  def self.call(...)
    new(...).call
  end
  public_class_method :call

  public

  def initialize(actor:, owner:, name:, title:)
    @actor = actor
    @owner = owner
    @name = name
    @title = title
  end

  def call
    validate_actor!

    OrgZenithRecord.transaction do
      OperatorAuthorityLock.acquire_for!(operator_id: owner.id)
      locked_owner = Operator.lock.find(owner.id)
      validate_owner_active!(locked_owner)
      unless Acme::OrganizationQuotaPolicy.new(surface: :org, principal: locked_owner).allowed?
        raise QuotaExceeded, "operator #{owner.id} cannot create another organization"
      end

      bureau = Bureau.create!(name:, title:)
      BureauLifecycle.create!(
        bureau:,
        state: AuthorityResourceLifecycleStateValue::ACTIVE,
      )
      BureauOwnership.create!(bureau:, operator: locked_owner, ownership_revision: 0)
      bureau
    end
  end

  private

  attr_reader :actor, :owner, :name, :title

  def validate_actor!
    return if actor.instance_of?(Operator) && owner.instance_of?(Operator) && actor.id == owner.id

    raise InvalidActor, "the authenticated operator must become the owner"
  end

  def validate_owner_active!(locked_owner)
    return if locked_owner.status_id == OperatorStatus::ACTIVE &&
      locked_owner.login_allowed? &&
      locked_owner.access_enabled?

    raise InactiveOwner, "the owner is not allowed to create a bureau"
  end
end
