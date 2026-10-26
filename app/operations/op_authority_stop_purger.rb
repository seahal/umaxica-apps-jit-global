# typed: false
# frozen_string_literal: true

# Retention of OP authority-stop records (two.md 5.8 v2, D-172 S-2). A stop shares the retention of
# the roots it ended: when those roots become purge-eligible the stop and its children are deleted
# first (children before the stop), but never while a participant has not reached a final state.
# Returns the root ids that stay held because a stop referencing them is not final yet.
class OpAuthorityStopPurger
  CHILDREN = %i(browser_logout participant epoch_cutoff grant_target root_target).freeze

  class << self
    public

    def release_roots!(realm:, root_ids:)
      ids = Array(root_ids)
      return [] if ids.empty?

      config = OpAuthorityStopCommitter::REALMS.fetch(realm.to_s)
      stop_class = config.fetch(:stop)
      stop_ids = stop_ids_for_roots(config, ids)
      return [] if stop_ids.empty?

      stop_class.transaction do
        stops = stop_class.where(id: stop_ids).order(:id).lock.to_a
        stop_ids = stops.map(&:id)
        next [] if stop_ids.empty?

        roots_by_stop = target_root_ids_by_stop(config, stop_ids)
        purgeable_stop_ids = purgeable_stop_ids(config, roots_by_stop)
        delete_stops!(config, stops, purgeable_stop_ids)
        held_root_ids(roots_by_stop, stop_ids, purgeable_stop_ids) & ids
      end
    end

    private

    def stop_ids_for_roots(config, root_ids)
      grant_ids = config.fetch(:grant).where(config.fetch(:root_key) => root_ids).pluck(:id)
      stop_ids = config.fetch(:root_target).where(root_id: root_ids).pluck(:stop_id)
      stop_ids.concat(config.fetch(:grant_target).where(grant_id: grant_ids).pluck(:stop_id))
      stop_ids.uniq!
      stop_ids
    end

    def target_root_ids_by_stop(config, stop_ids)
      roots_by_stop = Hash.new { |hash, stop_id| hash[stop_id] = [] }
      config.fetch(:root_target).where(stop_id: stop_ids).pluck(:stop_id, :root_id).each do |stop_id, root_id|
        roots_by_stop[stop_id] << root_id
      end
      grant_target_rows = config.fetch(:grant_target).where(stop_id: stop_ids).pluck(:stop_id, :grant_id)
      grant_ids = grant_target_rows.map(&:last)
      grant_ids.uniq!
      grant_roots = config.fetch(:grant).where(id: grant_ids).pluck(:id, config.fetch(:root_key)).to_h
      grant_target_rows.each do |stop_id, grant_id|
        roots_by_stop[stop_id] << grant_roots.fetch(grant_id)
      end
      roots_by_stop.each_value(&:uniq!)
      roots_by_stop
    end

    def purgeable_stop_ids(config, roots_by_stop)
      target_root_ids = []
      roots_by_stop.each_value { |root_ids| target_root_ids.concat(root_ids) }
      target_root_ids.uniq!
      now = config.fetch(:root).database_now
      purgeable_root_ids = config.fetch(:root).where(id: target_root_ids, purge_eligible_at: ..now).pluck(:id)
      root_eligible_stop_ids =
        roots_by_stop.filter_map do |stop_id, root_ids_for_stop|
          stop_id if root_ids_for_stop.any? && (root_ids_for_stop - purgeable_root_ids).empty?
        end
      open_stop_ids = open_participant_stop_ids(config.fetch(:participant), root_eligible_stop_ids)
      root_eligible_stop_ids - open_stop_ids
    end

    def open_participant_stop_ids(participant_class, stop_ids)
      open_stop_ids =
        participant_class.where(stop_id: stop_ids).order(:id).lock.filter_map do |participant|
          participant.stop_id unless OpAuthorityStopReference::FINAL_PARTICIPANT_STATUS_IDS.include?(participant.status_id)
        end
      open_stop_ids.uniq!
      open_stop_ids
    end

    def delete_stops!(config, stops, purgeable_stop_ids)
      CHILDREN.each do |key|
        config.fetch(key).where(stop_id: purgeable_stop_ids).find_each(&:destroy!)
      end
      # Child rows were deleted above and PostgreSQL RESTRICT FKs enforce that order. `delete`
      # avoids dependent-association traversal on this strict-loading authority record.
      stops.select { |stop| purgeable_stop_ids.include?(stop.id) }.each(&:delete)
    end

    def held_root_ids(roots_by_stop, stop_ids, purgeable_stop_ids)
      root_ids =
        roots_by_stop.filter_map do |stop_id, root_ids_for_stop|
          root_ids_for_stop if stop_ids.include?(stop_id) && purgeable_stop_ids.exclude?(stop_id)
        end
      root_ids.flatten!
      root_ids.uniq!
      root_ids
    end
  end
end
