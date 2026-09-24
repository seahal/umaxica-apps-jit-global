# typed: false
# frozen_string_literal: true

# Read-only family guard for the approved owner-authority cutover.
#
# The guard is deliberately fail-closed. It does not mutate ownership or lifecycle rows, and it
# never infers a resource lifecycle from the absence of lifecycle rows. The cutover operation uses
# this guard while holding the family resource-table lock, then records the immutable family marker.
# A family may only be switched after this guard reports an explicit lifecycle contract and every
# authority-required row has one approved ownership relation.
class AuthorityOwnerCutoverGuard
  NON_AUTHORITY_REQUIRED_RESOURCE_STATES = %i(inactive discarded deleted retained).freeze

  Result =
    Data.define(
      :surface,
      :resource_kind,
      :ready,
      :resource_count,
      :authoritative_owner_count,
      :unresolved_resources,
      :blocking_reasons,
      :cutover_established,
    ) do
      def ready?
        ready
      end

      def unresolved_count
        unresolved_resources.length
      end

      def cutover_established?
        cutover_established
      end
    end

  def self.call(...)
    new(...).call
  end
  public_class_method :call

  public

  def initialize(surface:, resource_kind:)
    @configuration = AuthorityOwnerMigrationInventory.configuration_for(
      surface:, resource_kind:,
    )
  end

  def call
    inventory = scoped_inventory
    details = inventory.details
    unresolved = unresolved_details(details)
    blocking_reasons = blocking_reasons_for(inventory, details, unresolved)

    Result.new(
      surface: configuration.fetch(:surface),
      resource_kind: configuration.fetch(:resource_kind),
      ready: blocking_reasons.empty?,
      resource_count: details.length,
      authoritative_owner_count: details.count { |detail| detail.fetch(:source_is_authoritative_owner) },
      unresolved_resources: unresolved,
      blocking_reasons: blocking_reasons,
      cutover_established: configuration.fetch(:cutover_class).established?,
    )
  end

  private

  attr_reader :configuration

  def scoped_inventory
    AuthorityOwnerMigrationInventory.call(
      surface: configuration.fetch(:surface),
      resource_kind: configuration.fetch(:resource_kind),
    )
  end

  def unresolved_details(details)
    authority_required_details = details.select { |detail| authority_required_resource?(detail) }
    authority_required_details.reject do |detail|
      detail.fetch(:source_is_authoritative_owner) &&
        detail.fetch(:authoritative_owner_eligible) &&
        detail.fetch(:resource_lifecycle_eligible)
    end
  end

  def authority_required_resource?(detail)
    NON_AUTHORITY_REQUIRED_RESOURCE_STATES.exclude?(
      detail.fetch(:resource_lifecycle_classification).to_sym,
    )
  end

  def blocking_reasons_for(inventory, details, unresolved)
    reasons = {}
    schema_state = inventory.summary.fetch(:authority_schema_state)
    reasons[:schema] = :authority_schema_not_applied unless schema_state == :applied

    # An empty family proves that the inventory found no rows; it does not prove
    # that the family has been completely mapped. Keep the cutover gate fail-closed.
    reasons[:ownership] = [:empty_resource_family] if details.empty?
    if unresolved.any?
      classifications = unresolved.map { |detail| detail.fetch(:classification) }
      classifications.uniq!
      reasons[:ownership] = classifications
    end

    if schema_state != :applied
      reasons[:resource_lifecycle] = :resource_lifecycle_schema_unavailable
    elsif unresolved.any? { |detail| !detail.fetch(:resource_lifecycle_eligible) }
      reasons[:resource_lifecycle] = :unresolved_resource_lifecycle
    end
    reasons
  end
end
