# typed: false
# frozen_string_literal: true

# Keeps the surface principal and owner-membership decision locked while its authorized
# Avatar-database mutation runs. Principal and membership rows share the surface's Zenith database;
# Avatar records remain in their own database. This orders mutations against principal disablement
# and membership revocation without writing to either authority database.
class AvatarOwnerMembershipLockService < ApplicationService
  AuthorizationDenied = Class.new(StandardError)

  class << self
    public

    def call(actor:, surface:, subject_public_id:, owner_collective_public_id:, permission:,
             &operation)
      new(
        actor: actor,
        surface: surface,
        subject_public_id: subject_public_id,
        owner_collective_public_id: owner_collective_public_id,
        permission: permission,
      ).call(&operation)
    end
  end

  def initialize(actor:, surface:, subject_public_id:, owner_collective_public_id:, permission:)
    super()
    @actor = actor
    @surface = surface.to_s
    @subject_public_id = subject_public_id.to_s
    @owner_collective_public_id = owner_collective_public_id.to_s
    @permission = permission.to_s
  end

  public

  def call
    raise ArgumentError, "Avatar owner mutation block is required" unless block_given?

    config =
      AvatarPermissionResolver::SURFACES.fetch(surface) do
        raise AuthorizationDenied, "unsupported Avatar owner surface"
      end
    actor_class = config.fetch(:actor)
    raise AuthorizationDenied, "Avatar owner actor does not match surface" unless actor.is_a?(actor_class)

    connection_owner = config.fetch(:authority_connection_owner)
    status_class = config.fetch(:actor_status)

    # Client/PersonaMembership and Operator/AgentMembership share their surface's
    # Zenith connection owner. Lock principal lifecycle before membership, then
    # retain both read locks until the Avatar write has completed.
    connection_owner.connected_to(role: :writing) do
      connection_owner.transaction do
        locked_actor = actor_class.lock.find(actor.id)
        unless locked_actor.status_id == status_class.const_get(:ACTIVE) &&
            locked_actor.login_allowed? && locked_actor.access_enabled?
          raise AuthorizationDenied, "Avatar owner actor must be active"
        end

        allowed = AvatarPermissionResolver.call(
          actor: locked_actor,
          surface: surface,
          subject_public_id: subject_public_id,
          owner_collective_public_id: owner_collective_public_id,
          permission: permission,
          lock: true,
        )
        raise AuthorizationDenied, "#{permission} permission required" unless allowed

        yield
      end
    end
  end

  private

  attr_reader :actor, :surface, :subject_public_id, :owner_collective_public_id, :permission
end
