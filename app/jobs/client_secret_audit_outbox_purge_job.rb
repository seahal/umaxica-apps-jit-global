# frozen_string_literal: true

class ClientSecretAuditOutboxPurgeJob < ApplicationJob
  queue_as :retention

  public

  def perform(batch_size: 500, after_id: 0, through_id: nil)
    unless batch_size.is_a?(Integer) && batch_size.between?(1, 500) &&
        after_id.is_a?(Integer) && after_id >= 0 &&
        (through_id.nil? || (through_id.is_a?(Integer) && through_id >= after_id))
      raise ArgumentError, "Secret outbox collection requires a bounded batch and ordered integer cursors"
    end
    return if FeatureFlags.enabled?(:retention_purge_suspended)

    AppZenithRecord.connected_to(role: :writing) do
      eligible = ClientSecretAuditOutbox.where.not(delivered_at: nil)
        .where(purge_eligible_at: ..Client.database_now)
      through_id = eligible.maximum(:id) if through_id.nil?
      return if through_id.nil?

      rows = eligible.where(id: (after_id + 1)..through_id).order(:id).limit(batch_size).to_a
      rows.each { |event| ClientSecretAuditOutboxPurger.call!(event: event) }
      return if rows.empty? || !eligible.exists?(id: (rows.last.id + 1)..through_id)

      ClientSecretAuditOutboxPurgeJob.perform_later(
        batch_size: batch_size, after_id: rows.last.id, through_id: through_id,
      )
    end
  end
end
