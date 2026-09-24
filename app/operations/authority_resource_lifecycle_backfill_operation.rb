# typed: false
# frozen_string_literal: true

# Adds one explicitly reviewed lifecycle state to one concrete resource.
#
# An absent lifecycle row is unresolved. This operation never assumes that an existing resource is
# active and never changes an existing state as a side effect of owner backfill.
class AuthorityResourceLifecycleBackfillOperation
  Result = Data.define(:status, :surface, :resource_kind, :resource_public_id, :state, :reason)

  class LifecycleConflict < StandardError; end

  def self.call(...)
    new(...).call
  end
  public_class_method :call

  public

  def initialize(surface:, resource_kind:, resource_public_id:, state: nil)
    @configuration = AuthorityOwnerMigrationInventory.configuration_for(
      surface:, resource_kind:,
    )
    @resource_public_id = resource_public_id.to_s
    @state = state.to_s.presence
  end

  def call
    return manual_review(:explicit_lifecycle_state_required) if state.blank?
    return manual_review(:authority_schema_not_applied) unless
      AuthorityOwnerMigrationInventory.authority_schema_state(surface: configuration.fetch(:surface)) == :applied
    return manual_review(:family_already_cut_over) if family_cut_over?

    normalized_state = AuthorityResourceLifecycleStateValue.normalize(state)
    resource = resource_class.find_by!(public_id: resource_public_id)

    resource_class.transaction do
      AuthorityOwnerMigrationInventory.lock_resource_family!(configuration)
      return manual_review(:family_already_cut_over) if family_cut_over?

      locked_resource = resource_class.lock.find(resource.id)
      lifecycle = lifecycle_class.lock.find_by(resource_foreign_key => locked_resource.id)
      return already_applied if lifecycle&.state == normalized_state
      raise LifecycleConflict, "resource #{resource_public_id} has lifecycle #{lifecycle.state}" if lifecycle

      lifecycle_class.create!(
        resource_foreign_key => locked_resource.id,
        "state" => normalized_state,
      )
      applied(normalized_state)
    end
  end

  private

  attr_reader :configuration, :resource_public_id, :state

  def resource_class
    configuration.fetch(:resource_class)
  end

  def lifecycle_class
    configuration.fetch(:lifecycle_class)
  end

  def resource_foreign_key
    configuration.fetch(:lifecycle_resource_foreign_key)
  end

  def family_cut_over?
    configuration.fetch(:cutover_class).established?
  end

  def manual_review(reason)
    Result.new(
      status: :manual_review,
      surface: configuration.fetch(:surface),
      resource_kind: configuration.fetch(:resource_kind),
      resource_public_id: resource_public_id,
      state: nil,
      reason:,
    )
  end

  def applied(normalized_state)
    Result.new(
      status: :applied,
      surface: configuration.fetch(:surface),
      resource_kind: configuration.fetch(:resource_kind),
      resource_public_id: resource_public_id,
      state: normalized_state,
      reason: nil,
    )
  end

  def already_applied
    Result.new(
      status: :already_applied,
      surface: configuration.fetch(:surface),
      resource_kind: configuration.fetch(:resource_kind),
      resource_public_id: resource_public_id,
      state: state,
      reason: nil,
    )
  end
end
