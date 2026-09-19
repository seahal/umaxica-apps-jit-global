# typed: false
# frozen_string_literal: true

class BaseSelectorBootstrapAuthority
  ISSUER = "base-selector-bootstrap"
  AUDIENCE = "base"

  def self.call(surface:, principal:)
    new(surface: surface, principal: principal).call
  end

  def initialize(surface:, principal:)
    @config = AcmeSelector.config_for(surface)
    @principal = principal
  end

  def call
    raise ArgumentError, "principal is required" unless principal.is_a?(config.principal_class)

    with_writing_connections do
      config.principal_class.lock.find(principal.id)
      bootstrap_result = nil

      transaction_owners.reduce(
        -> {
          ensure_reference_rows!
          rp_account = ensure_rp_account!
          identity = ensure_identity!
          account = ensure_account!(identity)
          assignment = ensure_account_assignment!(account: account, identity: identity)
          collective = ensure_collective_for(account)
          unit = ensure_root_unit!(collective)
          ensure_membership!(account: account, collective: collective, unit: unit)
          avatar = provision_avatar!(account: account, collective: collective)
          bind_avatar_account!(avatar: avatar, account: account) if avatar.present?

          bootstrap_result = BootstrapResult.new(
            rp_account: rp_account, identity: identity, account: account, assignment: assignment,
            collective: collective, unit: unit, avatar: avatar,
          )
        },
      ) { |inner, owner| -> { owner.transaction { inner.call } } }.call

      bootstrap_result
    end
  end

  private

  attr_reader :config, :principal

  BootstrapResult = Data.define(:rp_account, :identity, :account, :assignment, :collective, :unit, :avatar)

  def with_writing_connections(&block)
    connection_owners.reduce(block) do |inner, owner|
      -> { owner.connected_to(role: :writing, &inner) }
    end.call
  end

  def connection_owners
    result = [
      connection_owner(config.principal_class),
      connection_owner(config.rp_account_class),
      connection_owner(config.token_class),
      (connection_owner(Avatar) if config.requires_avatar),
    ].compact
    result.uniq!
    result
  end

  def transaction_owners
    result = [
      connection_owner(config.rp_account_class),
      connection_owner(config.identity_class),
      connection_owner(config.account_class),
      connection_owner(config.account_assignment_class),
      connection_owner(config.collective_class),
      connection_owner(config.unit_class),
      connection_owner(config.membership_class),
      (connection_owner(Avatar) if config.requires_avatar),
    ].compact
    result.uniq!
    result
  end

  def connection_owner(klass)
    owner = klass
    owner = owner.superclass until owner.connection_class? || owner == ApplicationRecord
    owner
  end

  def ensure_reference_rows!
    [
      config.identity_state_class,
      config.membership_kind_class,
      config.membership_state_class,
      (AvatarCapability if config.requires_avatar),
      (HandleStatus if config.requires_avatar),
    ].compact.each { |klass| klass.ensure_defaults! if klass.respond_to?(:ensure_defaults!) }

    AvatarCapability.find_or_create_by!(id: AvatarCapability::NORMAL) if config.requires_avatar
  end

  def ensure_rp_account!
    create_unique(config.rp_account_class, { config.rp_account_foreign_key => principal.id })
  end

  def ensure_identity!
    attributes = {
      issuer: ISSUER,
      subject: principal.public_id,
      audience: AUDIENCE,
      source_record_id: principal.id,
      status_id: config.identity_state_class::ACTIVE,
    }
    create_unique(config.identity_class, attributes, lookup: { source_record_id: principal.id })
  end

  def ensure_account!(identity)
    association_key = :"#{config.account_identity_association}_id"
    create_unique(
      config.account_class,
      { association_key => identity.id, :moniker => config.account_moniker, :title => config.account_title },
      lookup: { association_key => identity.id },
    )
  end

  def ensure_account_assignment!(account:, identity:)
    create_unique(
      config.account_assignment_class,
      {
        config.account_assignment_account_key => account.id,
        config.account_assignment_identity_key => identity.id,
      },
      lookup: {
        config.account_assignment_account_key => account.id,
        config.account_assignment_identity_key => identity.id,
      },
    )
  end

  def ensure_collective_for(account)
    membership = account.current_memberships.first
    return membership.collective if membership.present?

    config.collective_class.create!(name: config.collective_name, title: config.collective_title)
  end

  def ensure_root_unit!(collective)
    collective.root_units.order(:created_at, :id).first ||
      config.unit_class.create!(config.unit_collective_association => collective, :name => "Default")
  end

  def ensure_membership!(account:, collective:, unit:)
    existing = account.memberships.current.primary_first.first
    return existing if existing.present?

    config.membership_class.create!(
      config.membership_account_association => account,
      config.membership_collective_association => collective,
      config.membership_unit_association => unit,
      :membership_kind_id => config.membership_kind_class::OWNER,
      :membership_state_id => config.membership_state_class::ACTIVE,
      :primary => true,
      :metadata => {},
      :starts_at => Time.current,
    )
  rescue ActiveRecord::RecordNotUnique
    account.memberships.current.primary_first.first || raise
  end

  def provision_avatar!(account:, collective:)
    # The avatar hook is always part of the surface bootstrap interface.
    # App persists an avatar; com/org traverse the same hook and return nil.
    return nil unless config.requires_avatar

    existing_avatar = AvatarAssignment.where(user_id: principal.id, role: "owner").first&.avatar
    return existing_avatar if existing_avatar.present?

    result = AvatarProvisioning::Create.call(
      actor: principal,
      subject_type: subject_type_for(account),
      subject: account,
      avatar_params: { moniker: "Default Avatar" },
      handle_params: { handle: default_handle },
      organization_public_id: collective.public_id,
    )

    raise result.errors.first if result.errors.any?

    result.avatar
  rescue ActiveRecord::RecordNotUnique, ActiveRecord::RecordInvalid
    AvatarAssignment.where(user_id: principal.id, role: "owner").first&.avatar || raise
  end

  def bind_avatar_account!(avatar:, account:)
    case account
    when ClientPersona
      AvatarPersonaBinding.find_or_create_by!(avatar: avatar, persona: account)
    when Agent
      AvatarAgentBinding.find_or_create_by!(avatar: avatar, agent: account)
    when Individual
      AvatarIndividualBinding.find_or_create_by!(avatar: avatar, individual: account)
    else
      raise ArgumentError, "unsupported account class: #{account.class.name}"
    end
  end

  def subject_type_for(account)
    case account
    when ClientPersona
      :persona
    when Agent
      :agent
    when Individual
      :individual
    else
      raise ArgumentError, "unsupported account class: #{account.class.name}"
    end
  end

  def default_handle
    "user-#{principal.public_id.downcase}"
  end

  def create_unique(klass, attributes, lookup: attributes)
    klass.find_or_create_by!(lookup) do |record|
      attributes.each { |key, value| record.public_send("#{key}=", value) }
    end
  rescue ActiveRecord::RecordNotUnique, ActiveRecord::RecordInvalid
    record = klass.find_by(lookup)
    return record if record.present?

    raise
  end
end
