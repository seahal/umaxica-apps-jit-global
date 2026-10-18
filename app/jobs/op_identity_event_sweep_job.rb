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
    OpIdentityEventInvalidator::REALMS.each do |event_class, realm|
      sweep(event_class, realm.fetch(:receipt))
    end
  end

  private

  def sweep(event_class, receipt_class)
    event_class.in_batches(of: BATCH_SIZE) do |batch|
      events = batch.to_a
      applied = receipt_class.where(event_id: events.map(&:event_id)).pluck(:event_id).to_set
      events.reject { |event| applied.include?(event.event_id) }.each { |event| apply(event) }
    end
  end

  # One failing event (OP unavailable) must not stop the rest; the next run retries it.
  def apply(event)
    OpIdentityEventInvalidator.call(event:)
  rescue ActiveRecord::ActiveRecordError => e
    Rails.error.report(e, handled: true, context: { event_id: event.event_id })
  end
end
