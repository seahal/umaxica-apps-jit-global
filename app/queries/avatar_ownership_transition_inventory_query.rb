# typed: false
# frozen_string_literal: true

require "json"

# Read-only inventory for the Avatar ownership cutover.
#
# This query reports facts needed by the operational backfill. It does not choose an owner,
# change a period, establish a cutover marker, or treat an unresolved row as safe to migrate.
class AvatarOwnershipTransitionInventoryQuery
  BATCH_SIZE = 500
  SURFACES = %w(app org).freeze
  READY_CLASSIFICATIONS = %w(ready concrete_only).freeze

  Result =
    Data.define(:summary, :details) do
      def ready?
        details.all? { |detail| READY_CLASSIFICATIONS.include?(detail.fetch(:classification)) }
      end

      def blocking?
        !ready?
      end

      def to_h = { summary: summary, details: details }

      def to_json(*) = JSON.pretty_generate(to_h)
    end

  class << self
    public

    def call(avatar_ids: nil)
      ids = normalize_ids(avatar_ids)
      details = []

      AvatarRecord.connected_to(role: :writing) do
        scope = Avatar.order(:id)
        scope = scope.where(id: ids) if ids
        scope.find_each(batch_size: BATCH_SIZE) do |avatar|
          details << inspect_avatar(avatar)
        end
      end

      classifications =
        details.each_with_object(Hash.new(0)) do |detail, counts|
          counts[detail.fetch(:classification)] += 1
        end

      Result.new(
        summary: {
          avatars_scanned: details.length,
          classifications: classifications.sort.to_h,
          ready: details.all? { |detail| READY_CLASSIFICATIONS.include?(detail.fetch(:classification)) },
        }.freeze,
        details: details.freeze,
      )
    end

    private

    def normalize_ids(avatar_ids)
      return nil if avatar_ids.nil?
      raise ArgumentError, "avatar_ids must be an Array" unless avatar_ids.is_a?(Array)
      raise ArgumentError, "avatar_ids must not be empty" if avatar_ids.empty?
      raise ArgumentError, "avatar_ids is limited to #{BATCH_SIZE} IDs" if avatar_ids.length > BATCH_SIZE

      ids =
        avatar_ids.map do |value|
          value.is_a?(Integer) ? value : Integer(value, 10)
        rescue ArgumentError, TypeError
          raise ArgumentError, "avatar_ids must contain positive integers"
        end
      raise ArgumentError, "avatar_ids must contain positive integers" if ids.any?(&:negative?) || ids.include?(0)

      ids.uniq.freeze
    end

    def inspect_avatar(avatar)
      base = {
        avatar_id: avatar.id,
        avatar_public_id: avatar.public_id,
        accessible: avatar.accessible?,
        legacy_owner_surface: nil,
        legacy_owner_collective_public_id: nil,
        concrete_owner_surface: nil,
        concrete_owner_public_id: nil,
      }

      return base.merge(classification: "deleted_avatar", action: "manual_review").freeze unless avatar.accessible?

      legacy_periods = avatar.avatar_ownership_periods.order(:valid_from, :id).to_a
      concrete_periods = concrete_periods_for(avatar)

      if pending_transfer?(avatar)
        return pending_detail(base, legacy_periods, concrete_periods)
      end

      if malformed_legacy?(legacy_periods) || malformed_concrete?(concrete_periods)
        return malformed_detail(base, legacy_periods, concrete_periods)
      end

      if legacy_periods.empty? && concrete_periods.empty?
        return base.merge(classification: "ownerless", action: "manual_review").freeze
      end

      if legacy_periods.empty?
        return concrete_only_detail(base, concrete_periods)
      end

      if concrete_periods.empty?
        return needs_backfill_detail(base, legacy_periods)
      end

      if matching_periods?(legacy_periods, concrete_periods)
        matching_detail(base, legacy_periods, concrete_periods)
      else
        base.merge(
          classification: "conflict",
          action: "manual_review",
          reason: "legacy and concrete ownership periods do not match",
          legacy_period_count: legacy_periods.length,
          concrete_period_count: concrete_periods.length,
        ).freeze
      end
    end

    def pending_detail(base, legacy_periods, concrete_periods)
      base.merge(
        classification: "pending_transfer",
        action: "wait_for_transfer_resolution",
        legacy_period_count: legacy_periods.length,
        concrete_period_count: concrete_periods.length,
      ).freeze
    end

    def malformed_detail(base, legacy_periods, concrete_periods)
      base.merge(
        classification: "conflict",
        action: "manual_review",
        reason: "ownership period contains a missing owner or invalid interval",
        legacy_period_count: legacy_periods.length,
        concrete_period_count: concrete_periods.length,
      ).freeze
    end

    def concrete_only_detail(base, concrete_periods)
      base.merge(
        classification: "concrete_only",
        action: "already_concrete",
        concrete_period_count: concrete_periods.length,
        concrete_owner_surface: concrete_periods.last&.fetch(:surface),
        concrete_owner_public_id: concrete_periods.last&.fetch(:public_id),
      ).freeze
    end

    def needs_backfill_detail(base, legacy_periods)
      base.merge(
        classification: "needs_backfill",
        action: "backfill_concrete_periods",
        legacy_period_count: legacy_periods.length,
        legacy_owner_surface: legacy_periods.last.owner_surface,
        legacy_owner_collective_public_id: legacy_periods.last.owner_collective_public_id,
      ).freeze
    end

    def matching_detail(base, legacy_periods, concrete_periods)
      base.merge(
        classification: "ready",
        action: "cutover_eligible",
        legacy_period_count: legacy_periods.length,
        concrete_period_count: concrete_periods.length,
        legacy_owner_surface: legacy_periods.last.owner_surface,
        legacy_owner_collective_public_id: legacy_periods.last.owner_collective_public_id,
        concrete_owner_surface: concrete_periods.last.fetch(:surface),
        concrete_owner_public_id: concrete_periods.last.fetch(:public_id),
      ).freeze
    end

    def concrete_periods_for(avatar)
      enterprise =
        avatar.enterprise_ownership_periods.order(:valid_from, :id).map do |period|
          {
            surface: "app",
            public_id: period.enterprise_public_id,
            valid_from: period.valid_from,
            valid_to: period.valid_to,
          }
        end
      bureau =
        avatar.bureau_ownership_periods.order(:valid_from, :id).map do |period|
          {
            surface: "org",
            public_id: period.bureau_public_id,
            valid_from: period.valid_from,
            valid_to: period.valid_to,
          }
        end
      (enterprise + bureau).sort_by { |period| [period.fetch(:valid_from), period.fetch(:valid_to)] }
    end

    def malformed_legacy?(periods)
      periods.any? do |period|
        AvatarOwnershipPeriod::OWNER_SURFACES.exclude?(period.owner_surface) ||
          period.owner_collective_public_id.blank? ||
          period.valid_from.blank? ||
          !valid_interval?(period.valid_from, period.valid_to)
      end
    end

    def malformed_concrete?(periods)
      periods.any? do |period|
        SURFACES.exclude?(period.fetch(:surface)) ||
          period.fetch(:public_id).blank? ||
          !valid_interval?(period.fetch(:valid_from), period.fetch(:valid_to))
      end
    end

    def valid_interval?(valid_from, valid_to)
      valid_from.present? && valid_to.present? && (positive_infinity?(valid_to) || valid_from < valid_to)
    end

    def positive_infinity?(value)
      value.respond_to?(:infinite?) && value.infinite? == 1
    end

    def matching_periods?(legacy_periods, concrete_periods)
      return false unless legacy_periods.length == concrete_periods.length

      legacy_periods.zip(concrete_periods).all? do |legacy, concrete|
        legacy.owner_surface == concrete.fetch(:surface) &&
          legacy.owner_collective_public_id == concrete.fetch(:public_id) &&
          legacy.valid_from == concrete.fetch(:valid_from) &&
          legacy.valid_to == concrete.fetch(:valid_to)
      end
    end

    def pending_transfer?(avatar)
      avatar.ownership_transfers.pending.exists? || avatar.transfer_reservations.pending.exists?
    end
  end
end
