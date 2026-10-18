# typed: false
# frozen_string_literal: true

require "json"

# Establishes the Avatar legacy-writer barrier only after an explicit quiescence assertion and a
# clean bounded inventory. This operation never performs the operational backfill itself.
class AvatarOwnershipCutoverOperation
  Result =
    Data.define(:status, :summary, :inventory, :group_inventory) do
      def established?
        ["established", "already_established"].include?(status)
      end

      def blocked?
        status == "blocked"
      end

      def to_h
        {
          status: status,
          summary: summary,
          inventory: inventory.to_h,
          group_inventory: group_inventory.to_h,
        }
      end

      def to_json(*) = JSON.pretty_generate(to_h)
    end

  class << self
    public

    def call(avatar_ids:, group_ids:, writer_quiesced:, apply: false, cutover_at: nil)
      validate_arguments!(avatar_ids, group_ids, writer_quiesced, apply, cutover_at)
      AvatarRecord.connected_to(role: :writing) do
        call_on_writer(avatar_ids, group_ids, writer_quiesced, apply, cutover_at)
      end
    end

    private

    def call_on_writer(avatar_ids, group_ids, writer_quiesced, apply, cutover_at)
      inventory = AvatarOwnershipTransitionInventoryQuery.call(avatar_ids: avatar_ids)
      group_inventory = AvatarGroupOwnershipTransitionInventoryQuery.call(group_ids: group_ids)

      return blocked_result(
        inventory, group_inventory, "legacy writers are not explicitly quiesced",
      ) unless writer_quiesced
      return blocked_result(
        inventory, group_inventory, "inventory contains rows that require review",
      ) unless inventory.selection_complete? && group_inventory.selection_complete? &&
        inventory.ready? && group_inventory.ready?

      if AvatarOwnershipCutover.established?
        return Result.new(
          status: "already_established", summary: { apply: apply }.freeze,
          inventory: inventory, group_inventory: group_inventory,
        )
      end

      return Result.new(
        status: "ready", summary: { apply: apply }.freeze,
        inventory: inventory, group_inventory: group_inventory,
      ) unless apply

      establish!(inventory, group_inventory, group_ids:, cutover_at: cutover_at)
    end

    def validate_arguments!(avatar_ids, group_ids, writer_quiesced, apply, cutover_at)
      unless avatar_ids.is_a?(Array) && avatar_ids.any? &&
          avatar_ids.length <= AvatarOwnershipTransitionInventoryQuery::BATCH_SIZE &&
          avatar_ids.all? { |id| id.is_a?(Integer) && id.positive? }
        raise ArgumentError, "Avatar cutover requires a bounded nonempty avatar_ids array"
      end
      unless group_ids.is_a?(Array) && group_ids.length <= AvatarGroupOwnershipTransitionInventoryQuery::BATCH_SIZE &&
          group_ids.all? { |id| id.is_a?(Integer) && id.positive? }
        raise ArgumentError, "Group cutover requires a bounded group_ids array"
      end
      raise ArgumentError, "writer_quiesced must be true or false" unless [true, false].include?(writer_quiesced)
      raise ArgumentError, "apply must be true or false" unless [true, false].include?(apply)
      return if cutover_at.nil? || cutover_at.is_a?(Time)

      raise ArgumentError, "cutover_at must be a Time"
    end

    def blocked_result(inventory, group_inventory, reason)
      Result.new(
        status: "blocked",
        summary: { apply: false, reason: reason }.freeze,
        inventory: inventory,
        group_inventory: group_inventory,
      )
    end

    def establish!(inventory, group_inventory, group_ids:, cutover_at:)
      marker = nil
      AvatarRecord.transaction(requires_new: true) do
        AvatarGroup.where(id: group_ids).order(:id).lock.load
        marker = AvatarOwnershipCutover.lock.current
        marker ||= AvatarOwnershipCutover.create!(
          id: AvatarOwnershipCutover::CUTOVER_ID,
          cutover_at: cutover_at || Avatar.database_now,
        )
      end
      status = marker.previously_new_record? ? "established" : "already_established"
      Result.new(
        status: status,
        summary: { apply: true, cutover_at: marker.cutover_at }.freeze,
        inventory: inventory,
        group_inventory: group_inventory,
      )
    rescue ActiveRecord::RecordNotUnique
      return Result.new(
        status: "already_established",
        summary: { apply: true, cutover_at: AvatarOwnershipCutover.current&.cutover_at }.freeze,
        inventory: inventory,
        group_inventory: group_inventory,
      ) if AvatarOwnershipCutover.established?

      raise
    end
  end
end
