# typed: false
# frozen_string_literal: true

# adr/unified-enforcement.md, Duration and expiry: convergent and idempotent
# only. Runtime in-force evaluation never depends on this job having run --
# it exists to close bookkeeping (ended_at, end_reason) and emit the
# `expired` audit event for Cases whose expires_at has passed, and to run
# the admin_locked refcount release when appropriate.
class EnforcementExpiryJob < ApplicationJob
  queue_as :retention

  CASE_CLASSES = [AppEnforcementCase, ComEnforcementCase, OrgEnforcementCase].freeze

  def perform(batch_size: 200)
    now = Time.current
    CASE_CLASSES.each do |case_class|
      case_class.includes(:principal_effect)
        .where(state: "active", ended_at: nil).where(expires_at: ..now).in_batches(of: batch_size) do |batch|
        batch.find_each { |enforcement_case| expire!(enforcement_case) }
      end
    end
  end

  private

  def expire!(enforcement_case)
    EnforcementCaseEndOperation.call(enforcement_case: enforcement_case, reason: "expired")
  rescue StandardError => e
    Rails.logger.error(
      JitLogEvent.format(
        "enforcement.expiry.failed",
        case_public_id: enforcement_case.public_id,
        error_class: e.class.name,
      ),
    )
  end
end
