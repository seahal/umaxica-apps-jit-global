# typed: false
# frozen_string_literal: true

# Periodic physical deletion of records past their `purged_at` window.
#
# The set-based `delete_all` here is the Accepted, ADR-sanctioned exception to
# the forbidden-method rule on `delete_all`: see
# `adr/retainable-concern-and-retention-purge.md` and the "ADR-sanctioned
# data-retention exceptions" section of
# `docs/reference/forbidden-rails-methods.md`. Do not rewrite it as row-by-row
# `destroy` -- the batch DELETE (FK cascades, no AR callbacks) is the intended
# behavior.
class RetentionPurgeJob < ApplicationJob
  queue_as :retention

  # Order matters: rows are deleted with `delete_all`, which fires DB-level FK
  # cascades but not AR callbacks. Tables that hold FK references with
  # ON DELETE CASCADE to other RETAINABLE rows MUST be listed *before* the
  # referenced parent -- otherwise the cascade will silently delete rows whose
  # `purged_at` is still Infinity. Concretely: `client_sign_up_flows.token_id`
  # -> `client_tokens.id` ON DELETE CASCADE, so ClientSignUpFlow/VisitorSignUpFlow
  # must precede ClientToken/VisitorToken. Verified by
  # `test/jobs/retention_purge_job_test.rb`.
  RETAINABLE_MODELS = %w(
    AppPreferenceChronicle ComPreferenceChronicle OrgPreferenceChronicle
    ClientChronicle OperatorChronicle
    ClientSignInFlow VisitorSignInFlow OperatorSignInFlow
    ClientSignOutFlow VisitorSignOutFlow OperatorSignOutFlow
    ClientWithdrawalFlow VisitorWithdrawalFlow
    ClientProcessorErasureNotification VisitorProcessorErasureNotification
    ClientPrivacyRequest VisitorPrivacyRequest
    ClientRetentionHold VisitorRetentionHold
    ClientSignUpFlow VisitorSignUpFlow OperatorSignUpFlow
    ClientSecretCredential VisitorSecretCredential OperatorSecretCredential
    Avatar Member OperatorWorkspaceAccount
    AppPreference OrgPreference ComPreference
    ClientEmail VisitorEmail ClientTelephone VisitorTelephone
    ClientPasskey VisitorPasskey
    ClientToken OperatorToken VisitorToken
    ClientVerification OperatorVerification VisitorVerification
    ClientStepUpSession OperatorStepUpSession VisitorStepUpSession
    AreaOccurrence ClientOccurrence VisitorOccurrence OperatorOccurrence ZipOccurrence
    DomainOccurrence IpOccurrence EmailOccurrence JwtOccurrence TelephoneOccurrence
    Client Visitor Operator
  ).filter_map(&:safe_constantize).freeze

  # Operational kill switch, not a retention rule: the flag exists so an
  # operator can stop irreversible deletion during an incident, a data
  # migration, or a legal hold that is not yet expressed as a hold record.
  # Every unit of work below is selected by a time window (`purged_at: ..now`),
  # so a skipped run is inherently catch-up safe -- the next unsuspended run
  # processes the accumulated backlog. Returning normally keeps the recurring
  # schedule (config/recurring.yml, every 15 minutes) as the retry mechanism;
  # raising would only requeue work that is deliberately paused.
  FEATURE_NAME = :retention_purge_suspended

  def perform(batch_size: 500)
    if FeatureFlags.enabled?(FEATURE_NAME)
      Rails.logger.warn(JitLogEvent.format("retention.purge.suspended"))
      return
    end

    now = Time.current
    SignUpArtifactCleanup.cleanup_pending!(now: now, batch_size: batch_size)

    RETAINABLE_MODELS.each do |klass|
      if [Client, Visitor].include?(klass)
        anonymize_accounts(klass, now: now, batch_size: batch_size)
        next
      end

      if klass == Operator
        purge_operators(now: now, batch_size: batch_size)
        next
      end

      next unless klass.column_names.include?("purged_at")

      klass.where(purged_at: ..now).in_batches(of: batch_size).delete_all
    end
  end

  private

  # Operator rows are removed set-based (no callbacks/`dependent:`), so their
  # non-audit cross-DB children must be purged explicitly before deletion.
  # Enforcement-blocked rows (D3 principal_hard_delete_blocked /
  # withdrawal_purge_blocked) are excluded from the batch delete entirely.
  def purge_operators(now:, batch_size:)
    Operator.where(purged_at: ..now).in_batches(of: batch_size) do |batch|
      blocked_ids = []
      batch.find_each do |operator|
        if enforcement_blocks_purge?(operator)
          blocked_ids << operator.id
          next
        end

        RetentionCrossDatabaseChildPurge.call(actor: operator)
      end
      batch.where.not(id: blocked_ids).delete_all
    end
  end

  # adr/unified-enforcement.md, Retention interaction / Purge protection.
  def enforcement_blocks_purge?(actor)
    case_class = enforcement_case_class_for(actor)
    return false unless case_class

    case_class.principal_effect_blocking?(actor.public_id, :withdrawal_purge_blocked) ||
      case_class.principal_effect_blocking?(actor.public_id, :principal_hard_delete_blocked)
  end

  def enforcement_case_class_for(actor)
    case actor
    when Client then AppEnforcementCase
    when Visitor then ComEnforcementCase
    when Operator then OrgEnforcementCase
    end
  end

  # Set `terminated_at` only AFTER PersonalDataAnonymizer succeeds. Otherwise a
  # mid-anonymization failure (cross-DB, can't be atomic) leaves the marker set
  # and subsequent runs skip the row via `where(terminated_at: nil)`, freezing
  # partial anonymization permanently -- a GDPR / PII compliance failure mode.
  def anonymize_accounts(klass, now:, batch_size:)
    klass.where(purged_at: ..now).where(terminated_at: nil).in_batches(of: batch_size) do |batch|
      batch.find_each do |actor|
        if active_retention_hold_for(actor, now: now)
          handle_actor_purge_skipped_by_hold(actor, now: now)
          next
        end

        # adr/unified-enforcement.md, Retention interaction: a Principal
        # Effect with withdrawal_purge_blocked or principal_hard_delete_blocked
        # skips purge the same way a retention hold does. No FK is involved
        # (Purge protection) -- this is the model-layer half of the guard;
        # the database trigger (D20) is the other half.
        if enforcement_blocks_purge?(actor)
          WithdrawalOccurrenceRecording.record!(subject: actor, event_type: "withdrawal.purge_skipped_by_enforcement")
          next
        end

        WithdrawalPersonalDataAnonymizer.call(actor: actor)
        if actor.respond_to?(:terminated_at=)
          actor.withdrawn_at = now if actor.respond_to?(:withdrawn_at=)
          actor.terminated_at = now
          actor.save!(validate: false)
        end
        WithdrawalOccurrenceRecording.record!(subject: actor, event_type: "withdrawal.purged")
        WithdrawalOccurrenceRecording.record!(subject: actor, event_type: "withdrawal.shredded")
      end
    end
  end

  def active_retention_hold_for(actor, now:)
    case actor
    when Client then actor.client_retention_holds.active_at(now).first
    when Visitor then actor.visitor_retention_holds.active_at(now).first
    end
  end

  def handle_actor_purge_skipped_by_hold(actor, now:)
    hold = active_retention_hold_for(actor, now: now)
    privacy_requests_for(actor).open_for_hold_block.find_each do |privacy_request|
      privacy_request.block_by_legal_hold!(
        retention_exception_code: hold&.reason_code.presence || "legal_hold",
        now: now,
      )
      WithdrawalOccurrenceRecording.record!(
        subject: actor,
        event_type: "privacy_erasure.blocked_by_legal_hold",
        context: {
          privacy_request_public_id: privacy_request.public_id,
          retention_hold_public_id: hold&.public_id,
          retention_exception_code: privacy_request.retention_exception_code,
        },
      )
    end
    WithdrawalOccurrenceRecording.record!(
      subject: actor,
      event_type: "withdrawal.purge_skipped_by_hold",
      context: {
        retention_hold_public_id: hold&.public_id,
        reason_code: hold&.reason_code,
      },
    )
  end

  def privacy_requests_for(actor)
    case actor
    when Client then actor.client_privacy_requests
    when Visitor then actor.visitor_privacy_requests
    else
      raise ArgumentError, "unsupported retention actor: #{actor.class.name}"
    end
  end
end
