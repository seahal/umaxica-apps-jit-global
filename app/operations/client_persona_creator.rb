# typed: false
# frozen_string_literal: true

# Creates a ClientPersona and its first ownership row without consulting the
# legacy assignment or membership graph.  The operation is deliberately not
# wired to a controller yet: the lifecycle state gate and old-data cutover are
# separate prerequisites for enabling the new authority path.
class ClientPersonaCreator
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

  def initialize(actor:, owner:, client_identity:, moniker: nil, title:)
    @actor = actor
    @owner = owner
    @client_identity = client_identity
    @moniker = moniker
    @title = title
  end

  def call
    validate_actor!
    validate_identity!(owner:)

    AppZenithRecord.transaction do
      ClientAuthorityLock.acquire_for!(client_id: owner.id)
      locked_owner = Client.lock.find(owner.id)
      validate_owner_active!(locked_owner)
      locked_identity = ClientIdentity.lock.find_by(id: client_identity.id)
      validate_identity!(identity: locked_identity, owner: locked_owner)
      raise QuotaExceeded, "client #{owner.id} owns the maximum number of personas" if owned_count >= LIMIT

      persona = ClientPersona.create!(
        client_identity: locked_identity,
        moniker: moniker,
        title: title,
      )
      ClientPersonaOwnership.create!(
        client_persona: persona,
        client: locked_owner,
        ownership_revision: 0,
      )
      persona
    end
  end

  private

  attr_reader :actor, :owner, :client_identity, :moniker, :title

  def validate_actor!
    return if actor.instance_of?(Client) && owner.instance_of?(Client) && actor.id == owner.id

    raise InvalidActor, "the authenticated client must become the owner"
  end

  def validate_identity!(identity: client_identity, owner:)
    valid_identity =
      identity.instance_of?(ClientIdentity) &&
      identity.source_record_id == owner.id &&
      identity.status_id == ClientIdentityState::ACTIVE
    return if valid_identity

    raise IdentityMismatch, "client identity is not an active binding for the owner"
  end

  def validate_owner_active!(locked_owner)
    return if locked_owner.status_id == ClientStatus::ACTIVE &&
      locked_owner.login_allowed? &&
      locked_owner.access_enabled?

    raise InactiveOwner, "the owner is not allowed to create a persona"
  end

  def owned_count
    ClientPersonaOwnership.where(client_id: owner.id).count
  end
end
