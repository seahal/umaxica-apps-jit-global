# typed: false
# frozen_string_literal: true

# Durable back-channel logout delivery from each realm OP outbox (R5-WU10, one.md section 7.6).
#
# Lease: a short OP transaction claims due rows (FOR UPDATE SKIP LOCKED), stamps a lease and an
# attempt, and commits. Delivery then happens with no transaction open. The outcome is recorded in
# another short transaction. A crashed worker's lease simply expires and a later run picks the row
# up again, so a queue outage or lost acknowledgement never loses the logout intent. The OP logout
# itself was already committed by OpLogoutCommitter; delivery success is a separate fact.
class OpOutboxDispatchJob < ApplicationJob
  queue_as :default

  OUTBOX_CLASSES = %w(OpAppOutboxEvent OpComOutboxEvent OpOrgOutboxEvent).freeze
  BATCH_SIZE = 50
  LEASE = 30.seconds
  MAX_BACKOFF = 1.hour

  public

  def perform
    OUTBOX_CLASSES.each { |name| dispatch(name.constantize) }
  end

  private

  def dispatch(outbox_class)
    lease(outbox_class).each do |event|
      next unless renew_lease(outbox_class, event)

      participant = event.logout_flow_participant
      outcome = OidcBackchannelLogoutClient.call(
        endpoint: event.target_endpoint_identity, logout_token: OpLogoutTokenIssuer.call(participant:),
      )
      record(outbox_class, event, participant, outcome)
    end
  end

  def lease(outbox_class)
    outbox_class.transaction do
      now = outbox_class.database_now
      events = outbox_class.lock("FOR UPDATE SKIP LOCKED").includes(:logout_flow_participant)
        .where(completed_at: nil).where(next_attempt_at: ..now)
        .where("lease_expires_at IS NULL OR lease_expires_at <= ?", now)
        .order(:next_attempt_at).limit(BATCH_SIZE).to_a
      events.each do |event|
        event.update!(
          lease_expires_at: now + LEASE, delivery_attempts: event.delivery_attempts + 1,
          dispatched_at: now,
        )
      end
      events
    end
  end

  def record(outbox_class, event, participant, outcome)
    outbox_class.transaction do
      current = outbox_class.lock.find(event.id)
      next if current.completed_at || current.delivery_attempts != event.delivery_attempts

      participant&.lock!
      now = outbox_class.database_now
      if outcome == :acknowledged
        current.update!(completed_at: now, lease_expires_at: nil, last_error_code: nil)
        participant&.update!(
          acknowledged_at: participant.acknowledged_at || now, completed_at: now,
          last_error_code: nil, delivery_attempts: current.delivery_attempts,
        )
      else
        exponent = [current.delivery_attempts, MAX_BACKOFF.to_i.bit_length].min
        backoff = [2**exponent, MAX_BACKOFF.to_i].min.seconds
        current.update!(next_attempt_at: now + backoff, lease_expires_at: nil, last_error_code: outcome)
        participant&.update!(last_error_code: outcome, delivery_attempts: current.delivery_attempts)
      end
    end
  end

  # A batch can take longer than one lease. Recheck ownership before each send so a reclaimed
  # row is not also sent by the old worker, and renew remaining rows without holding locks in HTTP.
  def renew_lease(outbox_class, event)
    outbox_class.transaction do
      current = outbox_class.lock.find(event.id)
      next false if current.completed_at || current.delivery_attempts != event.delivery_attempts

      current.update!(lease_expires_at: outbox_class.database_now + LEASE)
      true
    end
  end
end
