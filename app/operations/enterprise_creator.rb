# typed: false
# frozen_string_literal: true

# Creates an Enterprise and its first ownership row using the app surface's
# explicit authority tables.  The old membership graph is not consulted.
class EnterpriseCreator
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

    AppZenithRecord.transaction do
      ClientAuthorityLock.acquire_for!(client_id: owner.id)
      locked_owner = Client.lock.find(owner.id)
      validate_owner_active!(locked_owner)
      raise QuotaExceeded, "client #{owner.id} owns the maximum number of organizations" if owned_count >= LIMIT

      enterprise = Enterprise.create!(name: name, title: title)
      EnterpriseOwnership.create!(enterprise:, client: locked_owner, ownership_revision: 0)
      enterprise
    end
  end

  private

  attr_reader :actor, :owner, :name, :title

  def validate_actor!
    return if actor.instance_of?(Client) && owner.instance_of?(Client) && actor.id == owner.id

    raise InvalidActor, "the authenticated client must become the owner"
  end

  def validate_owner_active!(locked_owner)
    return if locked_owner.status_id == ClientStatus::ACTIVE &&
      locked_owner.login_allowed? &&
      locked_owner.access_enabled?

    raise InactiveOwner, "the owner is not allowed to create an organization"
  end

  def owned_count
    EnterpriseOwnership.where(client_id: owner.id).count
  end
end
