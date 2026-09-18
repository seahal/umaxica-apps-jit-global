# typed: false
# frozen_string_literal: true

# Terminalizes expired app/com sign-up tickets through the existing domain
# operation. The request-time state checks remain authoritative; this job only
# closes and cleans rows that were not reached while their flow was open.
class SignUpExpiryJob < ApplicationJob
  queue_as :retention

  TICKET_CLASSES = [ClientSignUpFlow, VisitorSignUpFlow].freeze

  public

  def perform(batch_size: 100)
    raise ArgumentError, "batch_size must be positive" unless batch_size.to_i.positive?

    now = Time.current
    TICKET_CLASSES.each do |ticket_class|
      expired_scope(ticket_class, now: now).in_batches(of: batch_size) do |batch|
        batch.each { |ticket| expire_ticket(ticket) }
      end
    end
  end

  private

  def expired_scope(ticket_class, now:)
    ticket_class
      .where(status_id: ticket_class.sign_up_in_progress_status_ids)
      .where(ticket_class.arel_table[:expires_at].lteq(now))
  end

  def expire_ticket(ticket)
    result = SignUpTermination.call(cycle: ticket, event: :expire, actor_context: nil)
    return if result.status == :expired || result.ticket&.status_id == ticket.class.status_id_for("EXPIRED")

    Rails.logger.warn(
      JitLogEvent.format(
        "sign_up.expiry.skipped",
        ticket_public_id: ticket.public_id,
        result_status: result.status,
      ),
    )
  rescue ActiveRecord::Deadlocked
    raise
  rescue StandardError => e
    Rails.logger.error(
      JitLogEvent.format(
        "sign_up.expiry.failed",
        ticket_public_id: ticket.public_id,
        error_class: e.class.name,
      ),
    )
  end
end
