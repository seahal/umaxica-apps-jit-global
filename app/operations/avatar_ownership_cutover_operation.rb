# typed: false
# frozen_string_literal: true

require "json"

# Establishes the Avatar legacy-writer barrier only after an explicit quiescence assertion and a
# clean bounded inventory. This operation never performs the operational backfill itself.
class AvatarOwnershipCutoverOperation
  Result =
    Data.define(:status, :summary, :inventory) do
      def established?
        ["established", "already_established"].include?(status)
      end

      def blocked?
        status == "blocked"
      end

      def to_h = { status: status, summary: summary, inventory: inventory.to_h }

      def to_json(*) = JSON.pretty_generate(to_h)
    end

  class << self
    public

    def call(avatar_ids:, writer_quiesced:, apply: false, cutover_at: nil)
      validate_arguments!(avatar_ids, writer_quiesced, apply, cutover_at)
      AvatarRecord.connected_to(role: :writing) do
        call_on_writer(avatar_ids, writer_quiesced, apply, cutover_at)
      end
    end

    private

    def call_on_writer(avatar_ids, writer_quiesced, apply, cutover_at)
      inventory = AvatarOwnershipTransitionInventoryQuery.call(avatar_ids: avatar_ids)

      return blocked_result(inventory, "legacy writers are not explicitly quiesced") unless writer_quiesced
      return blocked_result(inventory, "inventory contains rows that require review") unless inventory.ready?

      if AvatarOwnershipCutover.established?
        return Result.new(status: "already_established", summary: { apply: apply }.freeze, inventory: inventory)
      end

      return Result.new(status: "ready", summary: { apply: apply }.freeze, inventory: inventory) unless apply

      establish!(inventory, cutover_at: cutover_at)
    end

    def validate_arguments!(avatar_ids, writer_quiesced, apply, cutover_at)
      unless avatar_ids.is_a?(Array) && avatar_ids.any? &&
          avatar_ids.length <= AvatarOwnershipTransitionInventoryQuery::BATCH_SIZE &&
          avatar_ids.all? { |id| id.is_a?(Integer) && id.positive? }
        raise ArgumentError, "Avatar cutover requires a bounded nonempty avatar_ids array"
      end
      raise ArgumentError, "writer_quiesced must be true or false" unless [true, false].include?(writer_quiesced)
      raise ArgumentError, "apply must be true or false" unless [true, false].include?(apply)
      return if cutover_at.nil? || cutover_at.is_a?(Time)

      raise ArgumentError, "cutover_at must be a Time"
    end

    def blocked_result(inventory, reason)
      Result.new(
        status: "blocked",
        summary: { apply: false, reason: reason }.freeze,
        inventory: inventory,
      )
    end

    def establish!(inventory, cutover_at:)
      marker = nil
      AvatarRecord.transaction(requires_new: true) do
        marker = AvatarOwnershipCutover.lock.current
        marker ||= AvatarOwnershipCutover.create!(
          id: AvatarOwnershipCutover::CUTOVER_ID,
          cutover_at: cutover_at || Avatar.database_now,
        )
      end
      status = marker.previously_new_record? ? "established" : "already_established"
      Result.new(status: status, summary: { apply: true, cutover_at: marker.cutover_at }.freeze, inventory: inventory)
    rescue ActiveRecord::RecordNotUnique
      return Result.new(
        status: "already_established",
        summary: { apply: true, cutover_at: AvatarOwnershipCutover.current&.cutover_at }.freeze,
        inventory: inventory,
      ) if AvatarOwnershipCutover.established?

      raise
    end
  end
end
