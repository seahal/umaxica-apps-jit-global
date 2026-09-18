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
    ),
  }.freeze

  AUTHORITY_SCHEMA_STATES = %i(not_applied applied).freeze

  RESOURCE_CONFIGS = [
    {
      surface: :app,
      resource_kind: :client_persona,
      resource_class: ClientPersona,
      principal_class: Client,
      identity_association: :client_identity,
      identity_class: ClientIdentity,
      identity_active_status_id: ClientIdentityState::ACTIVE,
      principal_active_status_id: ClientStatus::ACTIVE,
      auto_backfill: false,
      recommended_action: :manual_review,
    },
    {
      surface: :app,
      resource_kind: :enterprise,
      resource_class: Enterprise,
      principal_class: Client,
      membership_association: :persona_memberships,
      membership_principal_association: :persona,
      identity_association: :client_identity,
      identity_class: ClientIdentity,
      identity_active_status_id: ClientIdentityState::ACTIVE,
      principal_active_status_id: ClientStatus::ACTIVE,
      auto_backfill: false,
      recommended_action: :manual_review,
    },
    {
      surface: :com,
      resource_kind: :individual,
      resource_class: Individual,
      principal_class: Visitor,
      identity_association: :visitor_identity,
      identity_class: VisitorIdentity,
      identity_active_status_id: VisitorIdentityState::ACTIVE,
      principal_active_status_id: VisitorStatus::ACTIVE,
      auto_backfill: false,
      recommended_action: :manual_review,
    },
    {
      surface: :com,
      resource_kind: :company,
      resource_class: Company,
      principal_class: Visitor,
      membership_association: :individual_memberships,
      membership_principal_association: :individual,
      identity_association: :visitor_identity,
      identity_class: VisitorIdentity,
      identity_active_status_id: VisitorIdentityState::ACTIVE,
      principal_active_status_id: VisitorStatus::ACTIVE,
      auto_backfill: false,
      recommended_action: :manual_review,
    },
    {
      surface: :org,
      resource_kind: :agent,
      resource_class: Agent,
      principal_class: Operator,
      identity_association: :operator_identity,
      identity_class: OperatorIdentity,
      identity_active_status_id: OperatorIdentityState::ACTIVE,
      principal_active_status_id: OperatorStatus::ACTIVE,
      auto_backfill: false,
      recommended_action: :manual_review,
    },
    {
      surface: :org,
      resource_kind: :bureau,
      resource_class: Bureau,
      principal_class: Operator,
      membership_association: :agent_memberships,
      membership_principal_association: :agent,
      identity_association: :operator_identity,
      identity_class: OperatorIdentity,
      identity_active_status_id: OperatorIdentityState::ACTIVE,
      principal_active_status_id: OperatorStatus::ACTIVE,
      auto_backfill: false,
      recommended_action: :manual_review,
    },
  ].each(&:freeze).freeze

  def self.call(...)
    new(...).call
  end
  public_class_method :call

  def initialize(now: Time.current)
    @now = now
  end

  public

  def call
    schema_state = authority_schema_state
    details = RESOURCE_CONFIGS.flat_map { |configuration| inventory_for(configuration) }
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

      resources.each do |resource|
        identity = resource.public_send(identity_association)
        principal = identity && principals.fetch(identity.source_record_id, nil)
        records << direct_detail(configuration, resource, identity, principal)
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

      resources.each do |resource|
        memberships = memberships_by_resource_id.fetch(resource.id, [])
        identities =
          memberships.filter_map do |membership|
            principal = membership.public_send(principal_association)
            principal&.public_send(identity_association)
          end
        principals = principals_for(configuration, identities)

        records << organization_detail(configuration, resource, memberships, principals)
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

  def direct_detail(configuration, resource, identity, principal)
    classification = legacy_candidate_classification(configuration, identity, principal)

    base_detail(configuration, resource).merge(
      classification:,
      legacy_identity_public_id: public_identifier(identity),
      candidate_principal: candidate_detail(configuration, identity, principal),
      source_is_authoritative_owner: false,
    )
  end

  def organization_detail(configuration, resource, memberships, principals)
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
    classification = memberships.empty? ? :no_legacy_owner_candidate : :membership_not_ownership

    base_detail(configuration, resource).merge(
      classification:,
      active_membership_count: memberships.length,
      candidate_principals: candidates,
      candidate_classifications: candidates.each_with_object(Hash.new(0)) { |candidate, counts|
        counts[candidate.fetch(:classification)] += 1
      },
      source_is_authoritative_owner: false,
    )
  end

  def base_detail(configuration, resource)
    {
      surface: configuration.fetch(:surface),
      resource_kind: configuration.fetch(:resource_kind),
      resource_public_id: public_identifier(resource),
      auto_backfill: configuration.fetch(:auto_backfill),
      recommended_action: configuration.fetch(:recommended_action),
    }
  end

  def legacy_candidate_classification(configuration, identity, principal)
    if identity.nil?
      :missing_identity_binding
    elsif identity.status_id != configuration.fetch(:identity_active_status_id)
      :inactive_identity_binding
    elsif principal.nil?
      :missing_principal
    elsif principal.status_id != configuration.fetch(:principal_active_status_id) ||
        !principal.login_allowed? || !principal.access_enabled?
      :inactive_principal
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

  def public_identifier(record)
    return nil unless record&.respond_to?(:public_id)

    record.public_id.presence
  end

  def authority_schema_state
    states =
      AUTHORITY_TABLES.each_with_object({}) do |(surface, table_names), result|
        configuration = RESOURCE_CONFIGS.find { |entry| entry.fetch(:surface) == surface }
        connection = configuration.fetch(:resource_class).connection
        result[surface] = table_names.index_with { |table_name| connection.data_source_exists?(table_name) }
      end
    present = states.values.flat_map(&:values)

    return :not_applied if present.none?
    return :applied if present.all?

    raise IncompleteAuthoritySchema, "authority schema is partially applied: #{states.inspect}"
  end
end
