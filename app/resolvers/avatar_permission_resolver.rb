# typed: false
# frozen_string_literal: true

# Resolves Avatar authority through the request actor's surface-specific Persona/Agent
# membership. Ownership periods identify the Organization; they do not grant its members
# permission by themselves.
class AvatarPermissionResolver
  PERMISSIONS = %w(
    avatar.view
    avatar.update
    avatar.group.manage
    avatar.group.attach
    avatar.group.detach
    avatar.transfer.request
    avatar.transfer.accept
    avatar.transfer.cancel
  ).freeze

  OWNER_PERMISSIONS = PERMISSIONS.to_set.freeze

  SURFACES = {
    "app" => {
      actor: Client,
      authority_connection_owner: AppZenithRecord,
      subject: ClientPersona,
      identity_association: :client_identity,
      identity_table: :client_identities,
      membership: PersonaMembership,
      collective_table: :enterprises,
      kind: PersonaMembershipKind,
    },
    "org" => {
      actor: Operator,
      actor_status: OperatorStatus,
      authority_connection_owner: OrgZenithRecord,
      subject: Agent,
      identity_association: :operator_identity,
      identity_table: :operator_identities,
      membership: AgentMembership,
      collective_table: :bureaus,
      kind: AgentMembershipKind,
    },
  }.freeze

  def self.call(...)
    new(...).call
  end

  def initialize(actor:, surface:, subject_public_id:, owner_collective_public_id:, permission:, lock: false,
                 avatar: nil)
    @actor = actor
    @surface = surface.to_s
    @subject_public_id = subject_public_id.to_s
    @owner_collective_public_id = owner_collective_public_id.to_s
    @permission = permission.to_s
    @lock = lock
    @avatar = avatar
  end

  def call
    raise ArgumentError, "unsupported Avatar permission" unless PERMISSIONS.include?(permission)

    config = SURFACES[surface]
    return false unless config
    return false unless actor.is_a?(config.fetch(:actor))
    return false if subject_public_id.blank? || owner_collective_public_id.blank?

    subject = find_subject(config)
    return false unless subject

    membership = find_membership(config, subject)
    return true if membership.present? && permissions_for_membership(membership, config).include?(permission)
    return false unless avatar.is_a?(Avatar)

    resolve_avatar_grant(subject)
  end

  private

  attr_reader :actor, :surface, :subject_public_id, :owner_collective_public_id, :permission, :lock, :avatar

  def find_subject(config)
    config.fetch(:subject)
      .joins(config.fetch(:identity_association))
      .where(public_id: subject_public_id)
      .where(config.fetch(:identity_table) => { source_record_id: actor.id })
      .first
  end

  def find_membership(config, subject)
    membership_class = config.fetch(:membership)
    scope = membership_class
      .active
      .joins(membership_class.collective_association_name)
      .where(membership_class.collective_association_name => { public_id: owner_collective_public_id })
      .where(membership_class.account_foreign_key => subject.id)
    return scope.first unless lock

    transaction_open = membership_class.connection_pool.with_connection(&:transaction_open?)
    raise ArgumentError, "membership lock requires an open membership transaction" unless transaction_open

    scope.lock("FOR UPDATE OF #{membership_class.quoted_table_name}").first
  end

  def resolve_avatar_grant(subject)
    concrete_period = current_concrete_period_for(owner_collective_public_id)
    concrete_period && AvatarAccessGrantResolver.call(
      avatar: avatar,
      ownership_period: concrete_period,
      subject: subject,
      capability: permission,
    )
  end

  def current_concrete_period_for(collective_public_id)
    case surface
    when "app"
      AvatarEnterpriseOwnershipPeriod.current.find_by(
        avatar_id: avatar.id,
        enterprise_public_id: collective_public_id,
      )
    when "org"
      AvatarBureauOwnershipPeriod.current.find_by(
        avatar_id: avatar.id,
        bureau_public_id: collective_public_id,
      )
    end
  end

  def permissions_for_membership(membership, config)
    return OWNER_PERMISSIONS if membership.membership_kind_id == config.fetch(:kind).const_get(:OWNER)

    Set.new
  end
end
