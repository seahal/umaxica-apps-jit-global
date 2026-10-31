# typed: false
# frozen_string_literal: true

# Recoverable sweep for Zenith identity stop events (R5-WU06, one.md section 7.5): applies every
# committed event that has no OP inbound receipt yet, regardless of age. The direct delivery after the Zenith
# commit and OpIdentityEventDeliveryJob are fast paths; a crash between the commit and either of
# them, a lost enqueue or exhausted retries leave the event unapplied, and this sweep closes that
# gap. Application is idempotent on the event ID (OpIdentityEventInvalidator).
class OpIdentityEventSweepJob < ApplicationJob
  queue_as :default

  BATCH_SIZE = 500

  public

  def perform
    failures = []
    OpIdentityEventInvalidator::REALMS.each do |event_class, realm|
      sweep(event_class, realm.fetch(:receipt), failures:)
    end
    raise failures.first if failures.any?
  end

  private

  def sweep(event_class, receipt_class, failures:)
    event_class.in_batches(of: BATCH_SIZE) do |batch|
      events = batch.to_a
      sender = OpIdentityEventInvalidator.receipt_sender(event_class)
      receipts =
        receipt_class.where(event_id: events.map(&:event_id), **sender)
          .index_by(&:event_id)
      candidates = events.select { |event| receipts.key?(event.event_id) }
      actor_class = OpIdentityEventInvalidator::REALMS.fetch(event_class).fetch(:actor)
      actor_ids = candidates.filter_map { |event| Integer(event.actor_ref, 10, exception: false) }
      actor_ids.uniq!
      actors = actor_class.where(id: actor_ids).pluck(:id, :public_id).to_h
      stops =
        OpAuthorityStopCommitter.stop_class(event_class::REALM)
          .where(authority_evidence_ref: candidates.map(&:event_id))
          .includes(:epoch_cutoff).group_by(&:authority_evidence_ref)
      events.each do |event|
        apply(event, failures:, receipt: receipts[event.event_id], actors:, stops:)
      end
    end
  rescue ActiveRecord::ActiveRecordError => e
    Rails.error.report(e, handled: true, context: { event_class: event_class.name })
  end

  # Preserve unexpected failures for the caller after processing other events and realms.
  def apply(event, failures:, receipt:, actors:, stops:)
    if receipt && OpIdentityEventInvalidator.receipt_matches_event?(
      event:, receipt:, actor_public_id: actors[Integer(event.actor_ref, 10, exception: false)],
      stops: stops.fetch(event.event_id, []),
    )
      return
    end

    OpIdentityEventInvalidator.call(event:)
  rescue ActiveRecord::ActiveRecordError => e
    Rails.error.report(e, handled: true, context: { event_id: event.event_id })
  rescue StandardError => e
    failures << e if failures.empty?
    Rails.error.report(e, handled: false, context: { event_id: event.event_id })
  end
end
