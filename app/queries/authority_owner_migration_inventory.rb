# typed: false
# frozen_string_literal: true

require "json"

# Read-only inventory for the pre-cutover authority migration.
class AuthorityOwnerMigrationInventory
  BATCH_SIZE = 500

  Result =
    Data.define(:summary, :details) do
      def to_h = { summary: summary, details: details }

      def to_json(*) = JSON.pretty_generate(to_h)
    end

  class IncompleteAuthoritySchema < StandardError; end

  # The table names are intentionally explicit. The inventory must fail when a surface has a
  # partial authority schema instead of silently treating that surface as ready.
  AUTHORITY_TABLES = {
    app: %w(
      client_authority_locks
      client_persona_ownerships
      client_persona_administration_grants
      client_persona_delegation_grants
      client_persona_usage_grants
      client_persona_view_grants
      enterprise_ownerships
      enterprise_administration_grants
      enterprise_delegation_grants
      enterprise_view_grants
      client_persona_ownership_transfer_requests
      enterprise_ownership_transfer_requests
      client_persona_lifecycles
      enterprise_lifecycles
      client_persona_authority_cutovers
      enterprise_authority_cutovers
    ),
    com: %w(
      visitor_authority_locks
      individual_ownerships
      individual_administration_grants
      individual_delegation_grants
      individual_usage_grants
      individual_view_grants
      company_ownerships
      company_administration_grants
      company_delegation_grants
      company_view_grants
      individual_ownership_transfer_requests
      company_ownership_transfer_requests
      individual_lifecycles
      company_lifecycles
      individual_authority_cutovers
      company_authority_cutovers
    ),
    org: %w(
      operator_authority_locks
      agent_ownerships
      agent_administration_grants
      agent_delegation_grants
      agent_usage_grants
      agent_view_grants
      bureau_ownerships
      bureau_administration_grants
      bureau_delegation_grants
      bureau_view_grants
      agent_ownership_transfer_requests
      bureau_ownership_transfer_requests
      agent_lifecycles
      bureau_lifecycles
      agent_authority_cutovers
      bureau_authority_cutovers
    ),
  }.freeze

  AUTHORITY_SCHEMA_STATES = %i(not_applied applied).freeze

  RESOURCE_KIND_BY_CATEGORY = {
    account: {
      app: :client_persona,
      com: :individual,
      org: :agent,
    },
    organization: {
      app: :enterprise,
      com: :company,
      org: :bureau,
    },
  }.each_value(&:freeze).freeze

  RESOURCE_CONFIGS = [
    {
      surface: :app,
      resource_kind: :client_persona,
      resource_class: ClientPersona,
      lifecycle_class: ClientPersonaLifecycle,
      lifecycle_resource_foreign_key: :client_persona_id,
      principal_class: Client,
      identity_association: :client_identity,
      identity_class: ClientIdentity,
      identity_active_status_id: ClientIdentityState::ACTIVE,
      principal_active_status_id: ClientStatus::ACTIVE,
      ownership_class: ClientPersonaOwnership,
      ownership_resource_foreign_key: :client_persona_id,
      ownership_principal_foreign_key: :client_id,
      ownership_principal_association: :client,
      administration_association: :administration_grants,
      administration_principal_association: :client,
      authority_lock_class: ClientAuthorityLock,
      authority_lock_principal_foreign_key: :client_id,
      cutover_class: ClientPersonaAuthorityCutover,
      auto_backfill: false,
      recommended_action: :manual_review,
    },
    {
      surface: :app,
      resource_kind: :enterprise,
      resource_class: Enterprise,
      lifecycle_class: EnterpriseLifecycle,
      lifecycle_resource_foreign_key: :enterprise_id,
      principal_class: Client,
      membership_association: :persona_memberships,
      membership_principal_association: :persona,
      identity_association: :client_identity,
      identity_class: ClientIdentity,
      identity_active_status_id: ClientIdentityState::ACTIVE,
      principal_active_status_id: ClientStatus::ACTIVE,
      ownership_class: EnterpriseOwnership,
      ownership_resource_foreign_key: :enterprise_id,
      ownership_principal_foreign_key: :client_id,
      ownership_principal_association: :client,
      administration_association: :administration_grants,
      administration_principal_association: :client,
      authority_lock_class: ClientAuthorityLock,
      authority_lock_principal_foreign_key: :client_id,
      cutover_class: EnterpriseAuthorityCutover,
      auto_backfill: false,
      recommended_action: :manual_review,
    },
    {
      surface: :com,
      resource_kind: :individual,
      resource_class: Individual,
      lifecycle_class: IndividualLifecycle,
      lifecycle_resource_foreign_key: :individual_id,
      principal_class: Visitor,
      identity_association: :visitor_identity,
      identity_class: VisitorIdentity,
      identity_active_status_id: VisitorIdentityState::ACTIVE,
      principal_active_status_id: VisitorStatus::ACTIVE,
      ownership_class: IndividualOwnership,
      ownership_resource_foreign_key: :individual_id,
      ownership_principal_foreign_key: :visitor_id,
      ownership_principal_association: :visitor,
      administration_association: :administration_grants,
      administration_principal_association: :visitor,
      authority_lock_class: VisitorAuthorityLock,
      authority_lock_principal_foreign_key: :visitor_id,
      cutover_class: IndividualAuthorityCutover,
      auto_backfill: false,
      recommended_action: :manual_review,
    },
    {
      surface: :com,
      resource_kind: :company,
      resource_class: Company,
      lifecycle_class: CompanyLifecycle,
      lifecycle_resource_foreign_key: :company_id,
      principal_class: Visitor,
      membership_association: :individual_memberships,
      membership_principal_association: :individual,
      identity_association: :visitor_identity,
      identity_class: VisitorIdentity,
      identity_active_status_id: VisitorIdentityState::ACTIVE,
      principal_active_status_id: VisitorStatus::ACTIVE,
      ownership_class: CompanyOwnership,
      ownership_resource_foreign_key: :company_id,
      ownership_principal_foreign_key: :visitor_id,
      ownership_principal_association: :visitor,
      administration_association: :administration_grants,
      administration_principal_association: :visitor,
      authority_lock_class: VisitorAuthorityLock,
      authority_lock_principal_foreign_key: :visitor_id,
      cutover_class: CompanyAuthorityCutover,
      auto_backfill: false,
      recommended_action: :manual_review,
    },
    {
      surface: :org,
      resource_kind: :agent,
      resource_class: Agent,
      lifecycle_class: AgentLifecycle,
      lifecycle_resource_foreign_key: :agent_id,
      principal_class: Operator,
      identity_association: :operator_identity,
      identity_class: OperatorIdentity,
      identity_active_status_id: OperatorIdentityState::ACTIVE,
      principal_active_status_id: OperatorStatus::ACTIVE,
      ownership_class: AgentOwnership,
      ownership_resource_foreign_key: :agent_id,
      ownership_principal_foreign_key: :operator_id,
      ownership_principal_association: :operator,
      administration_association: :administration_grants,
      administration_principal_association: :operator,
      authority_lock_class: OperatorAuthorityLock,
      authority_lock_principal_foreign_key: :operator_id,
      cutover_class: AgentAuthorityCutover,
      auto_backfill: false,
      recommended_action: :manual_review,
    },
    {
      surface: :org,
      resource_kind: :bureau,
      resource_class: Bureau,
      lifecycle_class: BureauLifecycle,
      lifecycle_resource_foreign_key: :bureau_id,
      principal_class: Operator,
      membership_association: :agent_memberships,
      membership_principal_association: :agent,
      identity_association: :operator_identity,
      identity_class: OperatorIdentity,
      identity_active_status_id: OperatorIdentityState::ACTIVE,
      principal_active_status_id: OperatorStatus::ACTIVE,
      ownership_class: BureauOwnership,
      ownership_resource_foreign_key: :bureau_id,
      ownership_principal_foreign_key: :operator_id,
      ownership_principal_association: :operator,
      administration_association: :administration_grants,
      administration_principal_association: :operator,
      authority_lock_class: OperatorAuthorityLock,
      authority_lock_principal_foreign_key: :operator_id,
      cutover_class: BureauAuthorityCutover,
      auto_backfill: false,
      recommended_action: :manual_review,
    },
  ].each(&:freeze).freeze

  def self.call(...)
    new(...).call
  end
  public_class_method :call

  def self.configuration_for(surface:, resource_kind:)
    RESOURCE_CONFIGS.find do |configuration|
      configuration.fetch(:surface) == surface.to_s.to_sym &&
        configuration.fetch(:resource_kind) == resource_kind.to_s.to_sym
    end || raise(ArgumentError, "unsupported authority resource: #{surface}/#{resource_kind}")
  end
  public_class_method :configuration_for

  def self.resource_kind_for(surface:, category:)
    category_mapping =
      RESOURCE_KIND_BY_CATEGORY.fetch(category.to_sym) do
        raise ArgumentError, "unsupported authority resource category: #{category.inspect}"
      end
    category_mapping.fetch(surface.to_sym) do
      raise ArgumentError, "unsupported authority resource surface: #{surface.inspect}"
    end
  end
  public_class_method :resource_kind_for

  def self.authority_schema_state(surface: nil)
    new.authority_schema_state(surface:)
  end
  public_class_method :authority_schema_state

  # A family cutover and each reviewed backfill share this short-lived table lock. It prevents a
  # new resource or a late backfill from passing the pre-cutover check while the family marker is
  # being committed. The table name comes only from the reviewed resource configuration.
  def self.lock_resource_family!(configuration)
    resource_class = configuration.fetch(:resource_class)
    connection = resource_class.connection
    table_name = connection.quote_table_name(resource_class.table_name)
    connection.execute("LOCK TABLE #{table_name} IN SHARE ROW EXCLUSIVE MODE")
  end
  public_class_method :lock_resource_family!

  def initialize(now: Time.current, surface: nil, resource_kind: nil)
    if resource_kind.present? && surface.blank?
      raise ArgumentError, "resource_kind requires a surface"
    end

    @now = now
    @surface = surface&.to_sym
    @resource_kind = resource_kind&.to_sym
  end

  public

  def call
    configurations = selected_configurations
    schema_state = authority_schema_state(surface: @surface)
    @authority_schema_applied = schema_state == :applied
    details = configurations.flat_map { |configuration| inventory_for(configuration) }
    summary = {
      authority_schema_state: schema_state,
      resources_scanned: details.length,
      classifications: details.each_with_object(Hash.new(0)) { |detail, counts|
        counts[detail.fetch(:classification)] += 1
      },
    }

    Result.new(summary:, details:)
  end

  private

  attr_reader :now

  def selected_configurations
    return RESOURCE_CONFIGS if @surface.nil?

    [self.class.configuration_for(surface: @surface, resource_kind: @resource_kind)]
  end

  def inventory_for(configuration)
    if configuration.key?(:membership_association)
      inventory_organizations(configuration)
    else
      inventory_direct_bindings(configuration)
    end
  end

  def inventory_direct_bindings(configuration)
    records = []
    resource_class = configuration.fetch(:resource_class)
    identity_association = configuration.fetch(:identity_association)

    resource_class.find_in_batches(batch_size: BATCH_SIZE) do |resources|
      preload_associations(resources, identity_association)
      identities = resources.filter_map { |resource| resource.public_send(identity_association) }
      principals = principals_for(configuration, identities)
      ownerships = ownerships_for(configuration, resources)
      administrators = administrators_for(configuration, resources)
      lifecycles = lifecycles_for(configuration, resources)

      resources.each do |resource|
        identity = resource.public_send(identity_association)
        principal = identity && principals.fetch(identity.source_record_id, nil)
        records << direct_detail(
          configuration,
          resource,
          identity,
          principal,
          ownerships.fetch(resource.id, nil),
          administrators.fetch(resource.id, []),
          lifecycles.fetch(resource.id, nil),
        )
      end
    end
    records
  end

  def inventory_organizations(configuration)
    records = []
    membership_association = configuration.fetch(:membership_association)
    principal_association = configuration.fetch(:membership_principal_association)
    identity_association = configuration.fetch(:identity_association)
    resource_class = configuration.fetch(:resource_class)
    membership_reflection = resource_class.reflect_on_association(membership_association)
    membership_class = membership_reflection.klass

    resource_class.find_in_batches(batch_size: BATCH_SIZE) do |resources|
      memberships_by_resource_id = memberships_for(
        membership_class,
        membership_reflection.foreign_key,
        resources,
        principal_association,
        identity_association,
      )
      ownerships = ownerships_for(configuration, resources)
      administrators = administrators_for(configuration, resources)
      lifecycles = lifecycles_for(configuration, resources)

      resources.each do |resource|
        memberships = memberships_by_resource_id.fetch(resource.id, [])
        identities =
          memberships.filter_map do |membership|
            principal = membership.public_send(principal_association)
            principal&.public_send(identity_association)
          end
        principals = principals_for(configuration, identities)

        records << organization_detail(
          configuration,
          resource,
          memberships,
          principals,
          ownerships.fetch(resource.id, nil),
          administrators.fetch(resource.id, []),
          lifecycles.fetch(resource.id, nil),
        )
      end
    end
    records
  end

  def preload_associations(records, associations)
    ActiveRecord::Associations::Preloader.new(records:, associations:).call
  end

  def principals_for(configuration, identities)
    principal_ids = identities.filter_map(&:source_record_id)
    principal_ids.uniq!
    configuration.fetch(:principal_class).where(id: principal_ids).index_by(&:id)
  end

  def ownerships_for(configuration, resources)
    return {} unless @authority_schema_applied

    ownership_class = configuration.fetch(:ownership_class)
    resource_foreign_key = configuration.fetch(:ownership_resource_foreign_key)
    principal_association = configuration.fetch(:ownership_principal_association)

    ownership_class
      .where(resource_foreign_key => resources.map(&:id))
      .includes(principal_association)
      .index_by { |ownership| ownership.public_send(resource_foreign_key) }
  end

  def lifecycles_for(configuration, resources)
    return {} unless @authority_schema_applied

    lifecycle_class = configuration.fetch(:lifecycle_class)
    lifecycle_foreign_key = configuration.fetch(:lifecycle_resource_foreign_key)

    lifecycle_class
      .where(lifecycle_foreign_key => resources.map(&:id))
      .index_by { |lifecycle| lifecycle.public_send(lifecycle_foreign_key) }
  end

  def administrators_for(configuration, resources)
    return {} unless @authority_schema_applied

    association = configuration.fetch(:administration_association)
    principal_association = configuration.fetch(:administration_principal_association)
    resource_class = configuration.fetch(:resource_class)
    reflection = resource_class.reflect_on_association(association)
    grant_class = reflection.klass

    grant_class
      .where(reflection.foreign_key => resources.map(&:id))
      .includes(principal_association)
      .to_a
      .group_by { |grant| grant.public_send(reflection.foreign_key) }
  end

  def memberships_for(membership_class, resource_foreign_key, resources, principal_association, identity_association)
    resource_ids = resources.map(&:id)
    membership_class
      .where(resource_foreign_key => resource_ids)
      .where(revoked_at: nil)
      .where(membership_state_id: membership_class.membership_state_active_id)
      .where("starts_at IS NULL OR starts_at <= ?", now)
      .where("ends_at IS NULL OR ends_at > ?", now)
      .includes(principal_association => identity_association)
      .to_a
      .group_by { |membership| membership.public_send(resource_foreign_key) }
  end

  def direct_detail(configuration, resource, identity, principal, ownership, administrators, lifecycle)
    owner_detail = authoritative_owner_detail(configuration, ownership)
    lifecycle_detail = resource_lifecycle_detail(lifecycle)
    classification =
      if ownership
        if !owner_detail.fetch(:authoritative_owner_eligible)
          :ineligible_authoritative_owner
        elsif !lifecycle_detail.fetch(:resource_lifecycle_eligible)
          :ineligible_authoritative_resource
        else
          :authoritative_owner_present
        end
      else
        legacy_candidate_classification(configuration, identity, principal)
      end

    base_detail(configuration, resource, lifecycle).merge(
      classification:,
      legacy_identity_public_id: public_identifier(identity),
      candidate_principal: candidate_detail(configuration, identity, principal),
      administrator_public_ids: administrator_public_ids(configuration, administrators),
      **owner_detail,
    )
  end

  def organization_detail(configuration, resource, memberships, principals, ownership, administrators, lifecycle)
    owner_detail = authoritative_owner_detail(configuration, ownership)
    lifecycle_detail = resource_lifecycle_detail(lifecycle)
    candidates =
      memberships.filter_map do |membership|
        resource_principal = membership.public_send(configuration.fetch(:membership_principal_association))
        identity = resource_principal&.public_send(configuration.fetch(:identity_association))
        principal = identity && principals.fetch(identity.source_record_id, nil)
        candidate_detail(configuration, identity, principal, legacy_resource: resource_principal)
      end
    candidates.uniq! do |candidate|
      candidate.values_at(:identity_public_id, :principal_public_id, :legacy_resource_public_id)
    end
    classification =
      if ownership
        if !owner_detail.fetch(:authoritative_owner_eligible)
          :ineligible_authoritative_owner
        elsif !lifecycle_detail.fetch(:resource_lifecycle_eligible)
          :ineligible_authoritative_resource
        else
          :authoritative_owner_present
        end
      elsif memberships.empty? && administrators.present?
        :administrator_only
      elsif memberships.empty?
        :no_legacy_owner_candidate
      elsif candidates.length > 1
        :ambiguous_legacy_candidates
      elsif candidates.all? { |candidate| candidate.fetch(:classification) != :legacy_binding_candidate }
        :inactive_only_legacy_candidate
      else
        :membership_not_ownership
      end

    base_detail(configuration, resource, lifecycle).merge(
      classification:,
      active_membership_count: memberships.length,
      candidate_principals: candidates,
      candidate_classifications: candidates.each_with_object(Hash.new(0)) { |candidate, counts|
        counts[candidate.fetch(:classification)] += 1
      },
      administrator_public_ids: administrator_public_ids(configuration, administrators),
      **owner_detail,
    )
  end

  def authoritative_owner_detail(configuration, ownership)
    return {
      authoritative_owner_public_id: nil,
      authoritative_owner_classification: nil,
      authoritative_owner_eligible: false,
      source_is_authoritative_owner: false,
    } unless ownership

    principal = ownership.public_send(configuration.fetch(:ownership_principal_association))
    eligible = principal.present? && principal_eligible?(configuration, principal)

    {
      authoritative_owner_public_id: public_identifier(principal),
      authoritative_owner_classification: principal.present? ?
        principal_lifecycle_classification(configuration, principal) : :missing_principal,
      authoritative_owner_eligible: eligible,
      source_is_authoritative_owner: true,
    }
  end

  def principal_eligible?(configuration, principal)
    principal.status_id == configuration.fetch(:principal_active_status_id) &&
      principal.login_allowed? &&
      principal.access_enabled?
  end

  def principal_lifecycle_classification(configuration, principal)
    return :inactive_principal unless principal.status_id == configuration.fetch(:principal_active_status_id)
    return :suspended_principal unless principal.login_allowed? && principal.access_enabled?

    :active_principal
  end

  def base_detail(configuration, resource, lifecycle)
    {
      surface: configuration.fetch(:surface),
      resource_kind: configuration.fetch(:resource_kind),
      resource_public_id: public_identifier(resource),
      auto_backfill: configuration.fetch(:auto_backfill),
      recommended_action: configuration.fetch(:recommended_action),
      **resource_lifecycle_detail(lifecycle),
    }
  end

  def resource_lifecycle_detail(lifecycle)
    return {
      resource_lifecycle_eligible: false,
      resource_lifecycle_classification: :unavailable,
    } unless @authority_schema_applied

    return {
      resource_lifecycle_eligible: false,
      resource_lifecycle_classification: :missing,
    } unless lifecycle

    eligible = lifecycle.active?
    {
      resource_lifecycle_eligible: eligible,
      resource_lifecycle_classification: lifecycle.state.to_sym,
    }
  end

  def legacy_candidate_classification(configuration, identity, principal)
    if identity.nil?
      :missing_identity_binding
    elsif identity.status_id != configuration.fetch(:identity_active_status_id)
      :inactive_identity_binding
    elsif principal.nil?
      :missing_principal
    elsif !principal_eligible?(configuration, principal)
      principal_lifecycle_classification(configuration, principal)
    else
      :legacy_binding_candidate
    end
  end

  def candidate_detail(configuration, identity, principal, legacy_resource: nil)
    return nil if identity.nil? && principal.nil? && legacy_resource.nil?

    {
      classification: legacy_candidate_classification(configuration, identity, principal),
      identity_public_id: public_identifier(identity),
      principal_public_id: public_identifier(principal),
      legacy_resource_public_id: public_identifier(legacy_resource),
    }
  end

  def administrator_public_ids(configuration, administrators)
    principal_association = configuration.fetch(:administration_principal_association)
    identifiers =
      administrators.filter_map do |administrator|
        public_identifier(administrator.public_send(principal_association))
      end
    identifiers.uniq!
    identifiers
  end

  def public_identifier(record)
    return nil unless record&.respond_to?(:public_id)

    record.public_id.presence
  end

  public

  def authority_schema_state(surface: nil)
    surfaces =
      if surface.present?
        selected_surface = surface.to_sym
        AUTHORITY_TABLES.fetch(selected_surface)
        [selected_surface]
      else
        AUTHORITY_TABLES.keys
      end
    states =
      AUTHORITY_TABLES.each_with_object({}) do |(surface_key, table_names), result|
        next unless surfaces.include?(surface_key)

        configuration = RESOURCE_CONFIGS.find { |entry| entry.fetch(:surface) == surface_key }
        connection = configuration.fetch(:resource_class).lease_connection
        result[surface_key] =
          table_names.index_with { |table_name| connection.data_source_exists?(table_name) }
      end
    present = states.values.flat_map(&:values)

    return :not_applied if present.none?
    return :applied if present.all?

    raise IncompleteAuthoritySchema, "authority schema is partially applied: #{states.inspect}"
  end
end
