# typed: false
# frozen_string_literal: true

# Applies one explicitly reviewed owner mapping and one explicitly reviewed resource lifecycle
# state as a single pre-deployment unit. The two lower-level operations remain reusable for
# inspection and isolated steps, but a caller that intends to advance a resource toward a family
# cutover must not leave one half of this pair committed.
class AuthorityOwnerPredeploymentBackfillOperation
  Result = Data.define(
    :status,
    :surface,
    :resource_kind,
    :resource_public_id,
    :owner_public_id,
    :lifecycle_state,
    :reason,
  )

  class BackfillRejected < StandardError
    attr_reader :reason

    def initialize(reason)
      @reason = reason
      super("pre-deployment backfill rejected: #{reason}")
    end
  end

  def self.call(...)
    new(...).call
  end
  public_class_method :call

  public

  def initialize(surface:, resource_kind:, resource_public_id:, owner_public_id:, lifecycle_state:)
    @configuration = AuthorityOwnerMigrationInventory.configuration_for(
      surface:, resource_kind:,
    )
    @resource_public_id = resource_public_id.to_s
    @owner_public_id = owner_public_id.to_s.presence
    @lifecycle_state = lifecycle_state.to_s.presence
  end

  def call
    return manual_review(:explicit_owner_required) if owner_public_id.blank?
    return manual_review(:explicit_lifecycle_state_required) if lifecycle_state.blank?
    return manual_review(:authority_schema_not_applied) unless
      AuthorityOwnerMigrationInventory.authority_schema_state(surface: configuration.fetch(:surface)) == :applied

    # Normalize before opening the transaction so an invalid state cannot be mistaken for a
    # partial migration. The lifecycle operation repeats its own validation at its public boundary.
    normalized_state = AuthorityResourceLifecycleStateValue.normalize(lifecycle_state)
    apply_backfills(normalized_state)
  rescue BackfillRejected => e
    manual_review(e.reason)
  end

  private

  def apply_backfills(normalized_state)
    result = nil
    resource_class.transaction do
      owner_result = AuthorityOwnerDirectBindingBackfillOperation.call(
        surface: configuration.fetch(:surface),
        resource_kind: configuration.fetch(:resource_kind),
        resource_public_id: resource_public_id,
        owner_public_id: owner_public_id,
      )
      unless %i(applied already_applied).include?(owner_result.status)
        result = manual_review(owner_result.reason)
        next
      end

      lifecycle_result = lifecycle_result_for(normalized_state)
      unless %i(applied already_applied).include?(lifecycle_result.status)
        raise BackfillRejected, lifecycle_result.reason
      end

      result = build_result(owner_result, lifecycle_result, normalized_state)
    end

    result
  end

  attr_reader :configuration, :resource_public_id, :owner_public_id, :lifecycle_state

  def resource_class
    configuration.fetch(:resource_class)
  end

  def lifecycle_result_for(normalized_state)
    AuthorityResourceLifecycleBackfillOperation.call(
      surface: configuration.fetch(:surface),
      resource_kind: configuration.fetch(:resource_kind),
      resource_public_id: resource_public_id,
      state: normalized_state,
    )
  rescue AuthorityResourceLifecycleBackfillOperation::LifecycleConflict
    raise BackfillRejected, :lifecycle_conflict
  end

  def build_result(owner_result, lifecycle_result, normalized_state)
    status =
      if owner_result.status == :already_applied && lifecycle_result.status == :already_applied
        :already_applied
      else
        :applied
      end
    Result.new(
      status:,
      surface: configuration.fetch(:surface),
      resource_kind: configuration.fetch(:resource_kind),
      resource_public_id: resource_public_id,
      owner_public_id: owner_result.owner_public_id,
      lifecycle_state: normalized_state,
      reason: nil,
    )
  end

  def manual_review(reason)
    Result.new(
      status: :manual_review,
      surface: configuration.fetch(:surface),
      resource_kind: configuration.fetch(:resource_kind),
      resource_public_id: resource_public_id,
      owner_public_id: nil,
      lifecycle_state: nil,
      reason:,
    )
  end
end
