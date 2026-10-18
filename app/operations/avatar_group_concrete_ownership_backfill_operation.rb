# typed: false
# frozen_string_literal: true

require "json"

# Idempotently copies only an unambiguous legacy Group ownership chain. This operation never
# changes the legacy source, invents a timestamp, or establishes the Avatar cutover marker.
class AvatarGroupConcreteOwnershipBackfillOperation
  BATCH_SIZE = AvatarGroupOwnershipTransitionInventoryQuery::BATCH_SIZE
  RESULT_BUCKETS = %i(would_backfill applied already_applied manual_review failed).freeze

  class CandidateRefused < StandardError; end

  Result =
    Data.define(:summary, :details) do
      def to_h = { summary: summary, details: details }

      def to_json(*) = JSON.pretty_generate(to_h)
    end

  class << self
    public

    def call(group_ids:, apply: false, output_path: nil)
      validate_arguments!(group_ids, apply, output_path)
      inventory = AvatarGroupOwnershipTransitionInventoryQuery.call(group_ids: group_ids)
      details = inventory.details.map { |candidate| process_candidate(candidate, apply: apply) }
      result = Result.new(summary: build_summary(details, apply: apply), details: details.freeze)
      write_report(result, output_path) if output_path.present?
      result
    end

    private

    def validate_arguments!(group_ids, apply, output_path)
      unless group_ids.is_a?(Array) && group_ids.any? && group_ids.length <= BATCH_SIZE &&
          group_ids.all? { |id| id.is_a?(Integer) && id.positive? }
        raise ArgumentError, "Group ownership backfill requires a nonempty bounded group_ids array"
      end
      raise ArgumentError, "apply must be true or false" unless [true, false].include?(apply)
      raise ArgumentError, "output_path must be a relative path" if
        output_path.present? && Pathname.new(output_path).absolute?
    end

    def process_candidate(candidate, apply:)
      case candidate.fetch(:classification)
      when "ready", "concrete_only"
        detail(candidate, :already_applied, "no concrete Group ownership backfill required", "no change")
      when "needs_backfill"
        apply ? apply_candidate(candidate) : detail(candidate, :would_backfill, "safe candidate observed", "dry_run")
      else
        detail(
          candidate,
          :manual_review,
          candidate[:reason] || "classification is not safe to backfill",
          "manual review required",
        )
      end
    end

    def apply_candidate(candidate)
      result = nil
      AvatarRecord.transaction(requires_new: true) do
        group = AvatarGroup.lock.find(candidate.fetch(:avatar_group_id))
        refreshed = AvatarGroupOwnershipTransitionInventoryQuery.call(group_ids: [group.id]).details.fetch(0)
        unless refreshed.fetch(:classification) == "needs_backfill"
          result = detail(candidate, :manual_review, "candidate changed before apply", "rerun inventory")
          next
        end

        legacy_periods = AvatarGroupOwnershipPeriod.where(avatar_group_id: group.id).lock.order(:valid_from, :id).to_a
        validate_candidate!(group, legacy_periods)
        legacy_periods.each { |period| create_concrete_period!(group, period) }
        result = detail(candidate, :applied, "created concrete Group ownership periods", "no change needed")
      end
      result
    rescue CandidateRefused => e
      detail(candidate, :manual_review, e.message, "manual review required")
    rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique, ActiveRecord::StatementInvalid => e
      detail(candidate, :failed, "#{e.class}: #{e.message.lines.first.to_s.strip}", "manual review required")
    end

    def validate_candidate!(group, periods)
      raise CandidateRefused, "Group ownership period is missing" if periods.empty?

      first = periods.first
      unless first.valid_from == group.created_at
        raise CandidateRefused, "initial Group ownership boundary is not group.created_at"
      end

      periods.each do |period|
        unless AvatarGroupConcreteOwnershipPeriod::OWNER_SURFACES.include?(period.owner_surface) &&
            period.owner_collective_public_id.present?
          raise CandidateRefused, "Group owner mapping is ambiguous"
        end
      end
    end

    def create_concrete_period!(group, period)
      AvatarGroupConcreteOwnershipPeriod.create!(
        avatar_group: group,
        owner_surface: period.owner_surface,
        owner_collective_public_id: period.owner_collective_public_id,
        valid_from: period.valid_from,
        valid_to: period.valid_to,
      )
    end

    def detail(candidate, bucket, reason, action)
      candidate.merge(backfill_bucket: bucket.to_s, reason: reason, action: action).freeze
    end

    def build_summary(details, apply:)
      summary = { apply: apply, total_candidates_scanned: details.length }
      RESULT_BUCKETS.each do |bucket|
        summary[bucket] = details.count { |detail| detail.fetch(:backfill_bucket) == bucket.to_s }
      end
      summary.freeze
    end

    def write_report(result, output_path)
      path = Rails.root.join(output_path)
      FileUtils.mkdir_p(path.dirname)
      File.write(path, result.to_json)
    end
  end
end
