# typed: false
# frozen_string_literal: true

# Establishes the irreversible point at which one reviewed resource family uses its explicit
# authority relation. The singleton marker is created only after the complete family guard passes.
# Backfill and resource-creation paths use the same family table lock so a concurrent write cannot
# pass a pre-cutover check and commit after this marker.
class AuthorityOwnerFamilyCutoverOperation
  Result = Data.define(
    :status,
    :surface,
    :resource_kind,
    :cutover_at,
    :blocking_reasons,
    :reason,
  )

  class CutoverRejected < StandardError
    attr_reader :reason

    def initialize(reason)
      @reason = reason
      super("authority family cutover rejected: #{reason}")
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
    return manual_review(:authority_schema_not_applied) unless
      AuthorityOwnerMigrationInventory.authority_schema_state(surface: configuration.fetch(:surface)) == :applied

    resource_class.transaction do
      AuthorityOwnerMigrationInventory.lock_resource_family!(configuration)

      existing = cutover_class.find_by(id: cutover_id)
      return already_cut_over(existing) if existing

      guard = AuthorityOwnerCutoverGuard.call(
        surface: configuration.fetch(:surface),
        resource_kind: configuration.fetch(:resource_kind),
      )
      unless guard.ready?
        return manual_review(
          :family_not_ready,
          blocking_reasons: guard.blocking_reasons,
        )
      end

      marker = cutover_class.create!(id: cutover_id)
      established(marker)
    end
  end

  private

  attr_reader :configuration

  def resource_class
    configuration.fetch(:resource_class)
  end

  def cutover_class
    configuration.fetch(:cutover_class)
  end

  def cutover_id
    cutover_class.const_get(:CUTOVER_ID)
  end

  def manual_review(reason, blocking_reasons: {})
    Result.new(
      status: :manual_review,
      surface: configuration.fetch(:surface),
      resource_kind: configuration.fetch(:resource_kind),
      cutover_at: nil,
      blocking_reasons:,
      reason:,
    )
  end

  def established(marker)
    Result.new(
      status: :established,
      surface: configuration.fetch(:surface),
      resource_kind: configuration.fetch(:resource_kind),
      cutover_at: marker.cutover_at,
      blocking_reasons: {},
      reason: nil,
    )
  end

  def already_cut_over(marker)
    Result.new(
      status: :already_cut_over,
      surface: configuration.fetch(:surface),
      resource_kind: configuration.fetch(:resource_kind),
      cutover_at: marker.cutover_at,
      blocking_reasons: {},
      reason: nil,
    )
  end
end
