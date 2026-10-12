# typed: false
# frozen_string_literal: true

require "json"

# Read-only inventory for the staged Group ownership-period transition. It never chooses an owner,
# changes a period, or treats a partial concrete copy as safe to cut over.
class AvatarGroupOwnershipTransitionInventoryQuery
  BATCH_SIZE = 500
  READY_CLASSIFICATIONS = %w(ready concrete_only).freeze

  Result =
    Data.define(:summary, :details) do
      def ready?
        details.length == summary.fetch(:groups_requested) &&
          details.all? { |detail| READY_CLASSIFICATIONS.include?(detail.fetch(:classification)) }
      end

      def selection_complete?
        summary.fetch(:selection_complete)
      end

      def blocking?
        !ready?
      end

      def to_h = { summary: summary, details: details }

      def to_json(*) = JSON.pretty_generate(to_h)
    end

  class << self
    public

    def call(group_ids:)
      ids = normalize_ids(group_ids)
      details = []

      AvatarRecord.connected_to(role: :writing) do
        AvatarGroup.where(id: ids).order(:id).find_each(batch_size: BATCH_SIZE) do |group|
          details << inspect_group(group)
        end
      end

      total_group_count = AvatarRecord.connected_to(role: :writing) { AvatarGroup.count }

      classifications =
        details.each_with_object(Hash.new(0)) do |detail, counts|
          counts[detail.fetch(:classification)] += 1
        end

      Result.new(
        summary: {
          groups_requested: ids.length,
          groups_scanned: details.length,
          selection_complete: details.length == total_group_count,
          classifications: classifications.sort.to_h,
          ready: details.length == ids.length &&
            details.all? { |detail| READY_CLASSIFICATIONS.include?(detail.fetch(:classification)) },
        }.freeze,
        details: details.freeze,
      )
    end

    private

    def normalize_ids(group_ids)
      raise ArgumentError, "group_ids must be an Array" unless group_ids.is_a?(Array)
      raise ArgumentError, "group_ids is limited to #{BATCH_SIZE} IDs" if group_ids.length > BATCH_SIZE

      ids =
        group_ids.map do |value|
          value.is_a?(Integer) ? value : Integer(value, 10)
        rescue ArgumentError, TypeError
          raise ArgumentError, "group_ids must contain positive integers"
        end
      raise ArgumentError, "group_ids must contain positive integers" if ids.any?(&:negative?) || ids.include?(0)

      ids.uniq.freeze
    end

    def inspect_group(group)
      base = {
        avatar_group_id: group.id,
        avatar_group_public_id: group.public_id,
        legacy_period_count: 0,
        concrete_period_count: 0,
        legacy_owner_surface: nil,
        legacy_owner_collective_public_id: nil,
        concrete_owner_surface: nil,
        concrete_owner_collective_public_id: nil,
      }
      legacy_periods = AvatarGroupOwnershipPeriod.where(avatar_group_id: group.id).order(:valid_from, :id).to_a
      concrete_periods =
        AvatarGroupConcreteOwnershipPeriod.where(avatar_group_id: group.id).order(:valid_from, :id).to_a

      malformed_reason = malformed_reason(legacy_periods, group.created_at) ||
        malformed_reason(concrete_periods, group.created_at)
      if malformed_reason
        return base.merge(
          classification: "conflict",
          action: "manual_review",
          reason: malformed_reason,
          legacy_period_count: legacy_periods.length,
          concrete_period_count: concrete_periods.length,
        ).freeze
      end

      if legacy_periods.empty? && concrete_periods.empty?
        return base.merge(
          classification: "ownerless",
          action: "manual_review",
        ).freeze
      end

      return concrete_only_detail(base, concrete_periods) if legacy_periods.empty?
      return needs_backfill_detail(base, legacy_periods) if concrete_periods.empty?

      return matching_detail(base, legacy_periods, concrete_periods) if matching?(legacy_periods, concrete_periods)

      base.merge(
        classification: "conflict",
        action: "manual_review",
        reason: "legacy and concrete Group ownership periods do not match",
        legacy_period_count: legacy_periods.length,
        concrete_period_count: concrete_periods.length,
      ).freeze
    end

    def malformed_reason(periods, group_created_at)
      return if periods.empty?

      invalid_owner_or_interval =
        periods.any? do |period|
          AvatarGroupConcreteOwnershipPeriod::OWNER_SURFACES.exclude?(period.owner_surface) ||
            period.owner_collective_public_id.blank? ||
            period.valid_from.blank? ||
            !valid_interval?(period.valid_from, period.valid_to)
        end
      if invalid_owner_or_interval
        return "Group ownership period contains a missing owner or invalid interval"
      end

      return "Group ownership periods do not form one uninterrupted chain" unless
        uninterrupted_chain?(periods, group_created_at)

      nil
    end

    def uninterrupted_chain?(periods, group_created_at)
      return false unless periods.one? { |period| positive_infinity?(period.valid_to) }
      return false unless periods.first&.valid_from == group_created_at

      periods.each_cons(2).all? { |previous, current| previous.valid_to == current.valid_from }
    end

    def valid_interval?(valid_from, valid_to)
      valid_from.present? && valid_to.present? &&
        (positive_infinity?(valid_to) || valid_from < valid_to)
    end

    def positive_infinity?(value)
      value.respond_to?(:infinite?) && value.infinite? == 1
    end

    def concrete_only_detail(base, periods)
      owner = periods.last
      base.merge(
        classification: "concrete_only",
        action: "already_concrete",
        concrete_period_count: periods.length,
        concrete_owner_surface: owner.owner_surface,
        concrete_owner_collective_public_id: owner.owner_collective_public_id,
      ).freeze
    end

    def needs_backfill_detail(base, periods)
      owner = periods.last
      base.merge(
        classification: "needs_backfill",
        action: "backfill_concrete_group_periods",
        legacy_period_count: periods.length,
        legacy_owner_surface: owner.owner_surface,
        legacy_owner_collective_public_id: owner.owner_collective_public_id,
      ).freeze
    end

    def matching_detail(base, legacy_periods, concrete_periods)
      owner = concrete_periods.last
      base.merge(
        classification: "ready",
        action: "cutover_eligible",
        legacy_period_count: legacy_periods.length,
        concrete_period_count: concrete_periods.length,
        legacy_owner_surface: legacy_periods.last.owner_surface,
        legacy_owner_collective_public_id: legacy_periods.last.owner_collective_public_id,
        concrete_owner_surface: owner.owner_surface,
        concrete_owner_collective_public_id: owner.owner_collective_public_id,
      ).freeze
    end

    def matching?(legacy_periods, concrete_periods)
      return false unless legacy_periods.length == concrete_periods.length

      legacy_periods.zip(concrete_periods).all? do |legacy, concrete|
        legacy.owner_surface == concrete.owner_surface &&
          legacy.owner_collective_public_id == concrete.owner_collective_public_id &&
          legacy.valid_from == concrete.valid_from &&
          legacy.valid_to == concrete.valid_to
      end
    end
  end
end
