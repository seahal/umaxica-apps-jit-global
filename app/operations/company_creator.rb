# typed: false
# frozen_string_literal: true

# Creates a com Company with the authenticated Visitor as its first owner.
class CompanyCreator
  class InvalidActor < StandardError; end

  class InactiveOwner < StandardError; end

  class QuotaExceeded < StandardError; end

  LIMIT = Acme::QuotaLimits::ORGANIZATION_LIMIT

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

    ComZenithRecord.transaction do
      VisitorAuthorityLock.acquire_for!(visitor_id: owner.id)
      locked_owner = Visitor.lock.find(owner.id)
      validate_owner_active!(locked_owner)
      raise QuotaExceeded, "visitor #{owner.id} owns the maximum number of organizations" if owned_count >= LIMIT

      company = Company.create!(name:, title:)
      CompanyOwnership.create!(company:, visitor: locked_owner, ownership_revision: 0)
      company
    end
  end

  private

  attr_reader :actor, :owner, :name, :title

  def validate_actor!
    return if actor.instance_of?(Visitor) && owner.instance_of?(Visitor) && actor.id == owner.id

    raise InvalidActor, "the authenticated visitor must become the owner"
  end

  def validate_owner_active!(locked_owner)
    return if locked_owner.status_id == VisitorStatus::ACTIVE &&
      locked_owner.login_allowed? &&
      locked_owner.access_enabled?

    raise InactiveOwner, "the owner is not allowed to create a company"
  end

  def owned_count
    CompanyOwnership.where(visitor_id: owner.id).count
  end
end
