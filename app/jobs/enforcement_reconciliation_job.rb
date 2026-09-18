# typed: false
# frozen_string_literal: true

# adr/unified-enforcement.md, Reconciliation: EnforcementCaseApplyOperation commits
# the security decision atomically, but session revocation and the audit
# write happen after commit and can fail independently. This job finds every
# active Case across all three realms whose convergent side effects have not
# yet completed (sessions_revoked_at / audited_at still nil) and retries
# them. Appeal decisions are also durable current-state work: a persisted
# approved appeal is enough to rediscover a Case-end/release that failed after
# the decision committed. Chronicle remains a separate database; this job does
# not turn it into a transactional outbox.
class EnforcementReconciliationJob < ApplicationJob
  queue_as :retention

  CASE_CLASSES = [AppEnforcementCase, ComEnforcementCase, OrgEnforcementCase].freeze
  APPEAL_CLASSES = [AppEnforcementAppeal, ComEnforcementAppeal, OrgEnforcementAppeal].freeze
  APPEAL_AUDITABLE_STATES = %w(submitted approved rejected).freeze

  def perform(batch_size: 200)
    CASE_CLASSES.each do |case_class|
      case_class.pending_convergence.in_batches(of: batch_size) do |batch|
        batch.find_each { |enforcement_case| reconcile!(enforcement_case) }
      end

      case_class.pending_end_convergence.in_batches(of: batch_size) do |batch|
        batch.find_each { |enforcement_case| reconcile_ended_case!(enforcement_case) }
      end
    end

    APPEAL_CLASSES.each do |appeal_class|
      appeal_class.where(state: APPEAL_AUDITABLE_STATES).in_batches(of: batch_size) do |batch|
        batch.find_each { |appeal| reconcile_appeal!(appeal) }
      end
    end
  end

  private

  def reconcile!(enforcement_case)
    enforcement_case.revoke_method_sessions! if enforcement_case.sessions_revoked_at.blank?
    enforcement_case.write_audit_event_once!("revocation_reconciled") if enforcement_case.audited_at.blank?
  rescue StandardError => e
    log_failure(enforcement_case.public_id, e)
  end

  def reconcile_ended_case!(enforcement_case)
    EnforcementCaseEndOperation.new(
      enforcement_case: enforcement_case,
      reason: enforcement_case.end_reason,
      ended_by_operator_public_id: enforcement_case.ended_by_operator_public_id,
    ).reconcile
  rescue StandardError => e
    log_failure(enforcement_case.public_id, e)
  end

  def reconcile_appeal!(appeal)
    enforcement_case = appeal.enforcement_case
    return unless enforcement_case

    if appeal.state == "approved"
      if enforcement_case.ended_at.present?
        EnforcementCaseEndOperation.new(
          enforcement_case: enforcement_case,
          reason: "appeal_approved",
          ended_by_operator_public_id: appeal.reviewer_operator_public_id,
        ).reconcile
      else
        EnforcementCaseEndOperation.call(
          enforcement_case: enforcement_case,
          reason: "appeal_approved",
          ended_by_operator_public_id: appeal.reviewer_operator_public_id,
        )
      end
    end

    enforcement_case.write_audit_event_once!("appeal_#{appeal.state}")
  rescue StandardError => e
    log_failure(appeal.public_id, e)
  end

  def log_failure(public_id, error)
    Rails.logger.error(
      JitLogEvent.format(
        "enforcement.reconciliation.failed",
        case_public_id: public_id,
        error_class: error.class.name,
      ),
    )
  end
end
