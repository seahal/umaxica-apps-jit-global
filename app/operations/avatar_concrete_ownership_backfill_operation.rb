# typed: false
# frozen_string_literal: true

require "json"

# Idempotent, bounded operational backfill for legacy Avatar ownership periods.
#
# This operation only copies an unambiguous legacy chain into its concrete owner-family table.
# It never invents dates, maps a legacy actor by guesswork, changes the legacy source, or
# establishes the writer cutover marker.
class AvatarConcreteOwnershipBackfillOperation
  BATCH_SIZE = AvatarOwnershipTransitionInventoryQuery::BATCH_SIZE
  RESULT_BUCKETS = %i(would_backfill applied already_applied manual_review failed).freeze

  class CandidateRefused < StandardError; end

  Result =
    Data.define(:summary, :details) do
      def to_h = { summary: summary, details: details }

      def to_json(*) = JSON.pretty_generate(to_h)
    end

  class << self
    public

    def call(avatar_ids:, apply: false, output_path: nil)
      validate_arguments!(avatar_ids, apply, output_path)
      inventory = AvatarOwnershipTransitionInventoryQuery.call(avatar_ids: avatar_ids)
      details = inventory.details.map { |candidate| process_candidate(candidate, apply: apply) }
      result = Result.new(summary: build_summary(details, apply: apply), details: details.freeze)
      write_report(result, output_path) if output_path.present?
      result
    end

    private

    def validate_arguments!(avatar_ids, apply, output_path)
      unless avatar_ids.is_a?(Array) && avatar_ids.any? && avatar_ids.length <= BATCH_SIZE
        raise ArgumentError, "Avatar ownership backfill requires a nonempty bounded avatar_ids array"
      end
      unless avatar_ids.all? { |id| id.is_a?(Integer) && id.positive? }
        raise ArgumentError, "avatar_ids must contain positive integers"
      end
      raise ArgumentError, "apply must be true or false" unless [true, false].include?(apply)
      raise ArgumentError,
            "output_path must be a relative path" if output_path.present? && Pathname.new(output_path).absolute?
    end

    def process_candidate(candidate, apply:)
      case candidate.fetch(:classification)
      when "ready", "concrete_only"
        detail(candidate, :already_applied, "no concrete ownership backfill required", "no change")
      when "needs_backfill"
        apply ? apply_candidate(candidate) : detail(candidate, :would_backfill, "safe candidate observed", "dry_run")
      else
        detail(
          candidate, :manual_review, candidate[:reason] || "classification is not safe to backfill",
          "manual review required",
        )
      end
    end

    def apply_candidate(candidate)
      result = nil

      AvatarRecord.transaction(requires_new: true) do
        avatar = Avatar.lock.find(candidate.fetch(:avatar_id))
        refreshed = AvatarOwnershipTransitionInventoryQuery.call(avatar_ids: [avatar.id]).details.fetch(0)
        unless refreshed.fetch(:classification) == "needs_backfill"
          result = detail(candidate, :manual_review, "candidate changed before apply", "rerun inventory")
          next
        end

        legacy_periods = avatar.avatar_ownership_periods.lock.order(:valid_from, :id).to_a
        validate_candidate!(avatar, legacy_periods)
        legacy_periods.each { |period| create_concrete_period!(avatar, period) }
        result = detail(candidate, :applied, "created concrete ownership periods", "no change needed")
      end

      result
    rescue CandidateRefused => e
      detail(candidate, :manual_review, e.message, "manual review required")
    rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique, ActiveRecord::StatementInvalid => e
      detail(candidate, :failed, "#{e.class}: #{e.message.lines.first.to_s.strip}", "manual review required")
    end

    def validate_candidate!(avatar, legacy_periods)
      raise CandidateRefused, "Avatar is not accessible" unless avatar.accessible?
      raise CandidateRefused, "legacy ownership period is missing" if legacy_periods.empty?

      first = legacy_periods.first
      unless first.valid_from == avatar.created_at
        raise CandidateRefused, "initial ownership boundary is not Avatar.created_at"
      end

      legacy_periods.each do |period|
        unless AvatarOwnershipPeriod::OWNER_SURFACES.include?(period.owner_surface) &&
            period.owner_collective_public_id.present? && period.transferred_by_actor_id.nil?
          raise CandidateRefused, "legacy owner or actor mapping is ambiguous"
        end
      end
    end

    def create_concrete_period!(avatar, period)
      attributes = {
        avatar: avatar,
        valid_from: period.valid_from,
        valid_to: period.valid_to,
        transferred_by_actor_public_id: nil,
      }

      case period.owner_surface
      when "app"
        AvatarEnterpriseOwnershipPeriod.create!(**attributes, enterprise_public_id: period.owner_collective_public_id)
      when "org"
        AvatarBureauOwnershipPeriod.create!(**attributes, bureau_public_id: period.owner_collective_public_id)
      else
        raise CandidateRefused, "unsupported legacy owner surface"
      end
    end

    def detail(candidate, bucket, reason, action)
      candidate.merge(
        backfill_bucket: bucket.to_s,
        reason: reason,
        action: action,
      ).freeze
    end

    def build_summary(details, apply:)
      summary = { apply: apply, total_candidates_scanned: details.length }
      RESULT_BUCKETS.each { |bucket|
        summary[bucket] =
          details.count { |detail|
            detail.fetch(:backfill_bucket) == bucket.to_s
          }
      }
      summary.freeze
    end

    def write_report(result, output_path)
      path = Rails.root.join(output_path)
      FileUtils.mkdir_p(path.dirname)
      File.write(path, result.to_json)
    end
  end
end
