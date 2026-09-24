# typed: false
# frozen_string_literal: true

# Applies a complete, explicitly reviewed owner/lifecycle mapping for one resource family.
#
# The input is a migration decision, not an inference request. Every row must identify its
# surface-local owner and lifecycle state. A family is applied atomically so a rejected row cannot
# leave an earlier row from the same reviewed batch committed. The operation does not switch an
# authorization consumer or interpret legacy relationships as ownership. Once its family cutover
# marker exists, this path is permanently ineligible for further backfill.
class AuthorityOwnerFamilyBackfillOperation
  Result = Data.define(:status, :surface, :resource_kind, :results, :reason)

  class InvalidMapping < StandardError; end

  class BackfillRejected < StandardError
    attr_reader :reason, :results

    def initialize(reason, results: [])
      @reason = reason
      @results = results
      super("authority family backfill rejected: #{reason}")
    end
  end

  def self.call(...)
    new(...).call
  end
  public_class_method :call

  public

  def initialize(surface:, resource_kind:, mappings:)
    @configuration = AuthorityOwnerMigrationInventory.configuration_for(
      surface:, resource_kind:,
    )
    @raw_mappings = mappings
  end

  def call
    return manual_review(:authority_schema_not_applied) unless
      AuthorityOwnerMigrationInventory.authority_schema_state(surface: configuration.fetch(:surface)) == :applied
    return manual_review(:family_already_cut_over) if family_cut_over?

    @mappings = normalize_mappings(raw_mappings)
    return manual_review(:empty_reviewed_mapping) if mappings.empty?

    validate_complete_resource_set!
    apply_family
  rescue InvalidMapping => e
    manual_review(e.message.to_sym)
  rescue BackfillRejected => e
    manual_review(e.reason, results: e.results)
  end

  private

  attr_reader :configuration, :mappings, :raw_mappings

  def normalize_mappings(raw_mappings)
    unless raw_mappings.is_a?(Array)
      raise InvalidMapping, :mappings_must_be_an_array
    end

    normalized =
      raw_mappings.map.with_index do |mapping, index|
        unless mapping.respond_to?(:fetch)
          raise InvalidMapping, :"mapping_#{index}_must_be_a_hash"
        end

        resource_public_id = mapping.fetch(:resource_public_id, nil).to_s.presence
        owner_public_id = mapping.fetch(:owner_public_id, nil).to_s.presence
        lifecycle_state = mapping.fetch(:lifecycle_state, nil).to_s.presence
        raise InvalidMapping, :"mapping_#{index}_resource_required" if resource_public_id.blank?
        raise InvalidMapping, :"mapping_#{index}_owner_required" if owner_public_id.blank?
        raise InvalidMapping, :"mapping_#{index}_lifecycle_required" if lifecycle_state.blank?

        {
          resource_public_id:,
          owner_public_id:,
          lifecycle_state: AuthorityResourceLifecycleStateValue.normalize(lifecycle_state),
        }.freeze
      rescue KeyError
        raise InvalidMapping, :"mapping_#{index}_fields_required"
      rescue ArgumentError
        raise InvalidMapping, :"mapping_#{index}_lifecycle_invalid"
      end

    resource_ids = normalized.map { |mapping| mapping.fetch(:resource_public_id) }
    raise InvalidMapping, :duplicate_resource_mapping if resource_ids.uniq.length != resource_ids.length

    # A stable lock order prevents two reviewed family batches from deadlocking when they
    # contain the same resources in different input order.
    normalized.sort_by { |mapping| mapping.fetch(:resource_public_id) }.freeze
  end

  def apply_family
    applied_results = []
    resource_class.transaction do
      AuthorityOwnerMigrationInventory.lock_resource_family!(configuration)
      raise BackfillRejected.new(:family_already_cut_over, results: applied_results) if family_cut_over?

      mappings.each do |mapping|
        result =
          begin
            AuthorityOwnerPredeploymentBackfillOperation.call(
              surface: configuration.fetch(:surface),
              resource_kind: configuration.fetch(:resource_kind),
              **mapping,
            )
          rescue AuthorityOwnerDirectBindingBackfillOperation::OwnershipConflict
            raise BackfillRejected.new(:ownership_conflict, results: applied_results)
          rescue AuthorityOwnerPredeploymentBackfillOperation::BackfillRejected => e
            raise BackfillRejected.new(e.reason, results: applied_results)
          end
        applied_results << result
        next if %i(applied already_applied).include?(result.status)

        raise BackfillRejected.new(result.reason, results: applied_results)
      end
    end

    status = (applied_results.all? { |result| result.status == :already_applied }) ? :already_applied : :applied
    Result.new(
      status:,
      surface: configuration.fetch(:surface),
      resource_kind: configuration.fetch(:resource_kind),
      results: applied_results,
      reason: nil,
    )
  end

  def validate_complete_resource_set!
    resource_ids = mappings.map { |mapping| mapping.fetch(:resource_public_id) }
    known_resource_count = resource_class.where(public_id: resource_ids).count
    return if known_resource_count == resource_ids.length &&
      !resource_class.where.not(public_id: resource_ids).exists?

    raise InvalidMapping, :family_mapping_incomplete
  end

  def manual_review(reason, results: [])
    Result.new(
      status: :manual_review,
      surface: configuration.fetch(:surface),
      resource_kind: configuration.fetch(:resource_kind),
      results:,
      reason:,
    )
  end

  def resource_class
    configuration.fetch(:resource_class)
  end

  def family_cut_over?
    configuration.fetch(:cutover_class).established?
  end
end
