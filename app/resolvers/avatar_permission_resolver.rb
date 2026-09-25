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

  def initialize(actor:, surface:, subject_public_id:, owner_collective_public_id:, permission:, lock: false)
    @actor = actor
    @surface = surface.to_s
    @subject_public_id = subject_public_id.to_s
    @owner_collective_public_id = owner_collective_public_id.to_s
    @permission = permission.to_s
    @lock = lock
  end

  def call
    raise ArgumentError, "unsupported Avatar permission" unless PERMISSIONS.include?(permission)

    config = SURFACES[surface]
    return false unless config
    return false unless actor.is_a?(config.fetch(:actor))
    return false if subject_public_id.blank? || owner_collective_public_id.blank?

    subject = config.fetch(:subject)
      .joins(config.fetch(:identity_association))
      .where(public_id: subject_public_id)
      .where(config.fetch(:identity_table) => { source_record_id: actor.id })
      .first
    return false unless subject

    membership_class = config.fetch(:membership)
    membership_scope = membership_class
      .active
      .joins(membership_class.collective_association_name)
      .where(
        membership_class.collective_association_name => {
          public_id: owner_collective_public_id,
        },
      )
      .where(membership_class.account_foreign_key => subject.id)
    if lock
      transaction_open = membership_class.connection_pool.with_connection(&:transaction_open?)
      raise ArgumentError, "membership lock requires an open membership transaction" unless transaction_open

      membership_scope = membership_scope.lock("FOR UPDATE OF #{membership_class.quoted_table_name}")
    end
    membership = membership_scope.first
    membership.present? && permissions_for_membership(membership, config).include?(permission)
  end

  private

  attr_reader :actor, :surface, :subject_public_id, :owner_collective_public_id, :permission, :lock

  def permissions_for_membership(membership, config)
    return OWNER_PERMISSIONS if membership.membership_kind_id == config.fetch(:kind).const_get(:OWNER)

    Set.new
  end
end
