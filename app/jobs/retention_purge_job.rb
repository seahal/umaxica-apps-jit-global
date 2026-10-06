# typed: false
# frozen_string_literal: true

# Periodic physical deletion of records past their `purge_eligible_at` window.
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

  DEFAULT_BATCH_SIZE = 500
  MAX_BATCH_SIZE = 500

  # Rows are deleted with `delete_all`, which applies database-level FK actions
  # but not AR callbacks. Sign-up flows retain their token references until
  # their own retention window is complete; the corresponding FKs are
  # ON DELETE RESTRICT, so a parent token cannot silently delete a child.
  # Child-before-parent ordering remains explicit for retention readability and
  # for any independently cascading relations that are added under review.
  RETAINABLE_MODELS = %w(
    AppPreferenceChronicle ComPreferenceChronicle OrgPreferenceChronicle
    ClientChronicle OperatorChronicle
    ClientSessionLimitResolutionTransaction VisitorSessionLimitResolutionTransaction
    OperatorSessionLimitResolutionTransaction
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
  # Every unit of work below is selected by a time window (`purge_eligible_at: ..now`),
  # so a skipped run is inherently catch-up safe -- the next unsuspended run
  # processes the accumulated backlog. Returning normally keeps the recurring
  # schedule (config/recurring.yml, every 15 minutes) as the retry mechanism;
  # raising would only requeue work that is deliberately paused.
  FEATURE_NAME = :retention_purge_suspended

  def perform(batch_size: DEFAULT_BATCH_SIZE)
    limit = normalized_batch_size(batch_size)
    unless limit&.between?(1, MAX_BATCH_SIZE)
      raise ArgumentError, "batch_size must be between 1 and #{MAX_BATCH_SIZE}"
    end

    if FeatureFlags.enabled?(FEATURE_NAME)
      Rails.logger.warn(JitLogEvent.format("retention.purge.suspended"))
      return
    end

    SignUpArtifactCleanup.cleanup_pending!(batch_size: limit)

    if ClientSecretIssuance.exists? || ClientSecretCredential.exists? || ClientSecretAuditOutbox.exists?
      ClientSecretLifecycleJob.perform_now(batch_size: limit)
    end

    RETAINABLE_MODELS.each do |klass|
      now = klass.database_now

      if klass == ClientSecretCredential
        next
      end

      if [Client, Visitor].include?(klass)
        anonymize_accounts(klass, now: now, batch_size: limit)
        next
      end

      if klass == Operator
        purge_operators(now: now, batch_size: limit)
        next
      end

      next unless klass.column_names.include?("purge_eligible_at")

      if [ClientSignInFlow, VisitorSignInFlow, OperatorSignInFlow].include?(klass)
        purge_sign_in_flows(klass, now: now, batch_size: limit)
        next
      end

      if klass == ClientSignUpFlow
        purge_client_authentication_flows(klass, now: now, batch_size: limit)
        next
      end

      if [ClientSessionLimitResolutionTransaction, VisitorSessionLimitResolutionTransaction,
          OperatorSessionLimitResolutionTransaction,].include?(klass)
        purge_session_limit_resolutions(klass, now: now, batch_size: limit)
        next
      end

      klass.where(purge_eligible_at: ..now).in_batches(of: limit).delete_all
    end
  end

  private

  def purge_client_authentication_flows(klass, now:, batch_size:)
    klass.where(purge_eligible_at: ..now).in_batches(of: batch_size) do |batch|
      klass.transaction do
        # Flow locking also excludes admission and session issuance. Source queries
        # acquire no source row locks, preserving the Client-before-flow lock order.
        references = batch.lock.pluck(:public_id)
        protected_references =
          if klass == ClientSignInFlow
            ClientSecretCredential.where(claim_sign_in_flow_ref: references).pluck(:claim_sign_in_flow_ref) +
              ClientSignInFlow.where(
                public_id: references, id: ClientSecretSignInReceipt.select(:sign_in_flow_id),
              ).pluck(:public_id) +
              ClientAuthCeremonySession.where(local_sign_in_flow_ref: references).pluck(:local_sign_in_flow_ref) +
              ClientSignInFlow.where(
                public_id: references,
                id: ClientOidcAuthorizationTransaction.select(:secret_sign_in_flow_id),
              )
                .pluck(:public_id)
          else
            ClientSecretIssuance.where(sign_up_flow_ref: references).pluck(:sign_up_flow_ref)
          end
        batch.where(public_id: references - protected_references).delete_all
      end
    end
  end

  def purge_sign_in_flows(klass, now:, batch_size:)
    klass.where(purge_eligible_at: ..now).in_batches(of: batch_size) do |batch|
      klass.transaction do
        batch.lock.to_a.each do |flow|
          next unless AuthAdmissionBindingPurger.purge_for_parent!(
            # The flow itself is selected only after its model-owned retention
            # deadline. Admission terminal facts need only cross the same
            # already-established boundary before the restrictive parent FK
            # can be removed.
            parent: flow, now:, retention_period: 1.second,
          )

          klass.where(id: flow.id).delete_all
        end
      end
    end
  end

  def purge_session_limit_resolutions(klass, now:, batch_size:)
    flow_class =
      case klass.name
      when "ClientSessionLimitResolutionTransaction" then ClientSignInFlow
      when "VisitorSessionLimitResolutionTransaction" then VisitorSignInFlow
      when "OperatorSessionLimitResolutionTransaction" then OperatorSignInFlow
      else
        raise FlowConfigurationError, "unsupported session-limit resolution class: #{klass.name}"
      end
    terminal_states = [klass::RESOLVED, klass::EXPIRED, klass::CANCELLED]
    parent_ids = flow_class.where(purge_eligible_at: ..now).select(:id)
    klass.where(state_id: terminal_states, sign_in_flow_id: parent_ids, purge_eligible_at: ..now)
      .in_batches(of: batch_size).delete_all
  end

  def normalized_batch_size(value)
    return value if value.is_a?(Integer)
    return Integer(value) if value.is_a?(String)

    nil
  rescue ArgumentError, TypeError
    nil
  end

  # Operator rows are removed set-based (no callbacks/`dependent:`), so their
  # non-audit cross-DB children must be purged explicitly before deletion.
  # Enforcement-blocked rows (D3 principal_hard_delete_blocked /
  # withdrawal_purge_blocked) are excluded from the batch delete entirely.
  def purge_operators(now:, batch_size:)
    Operator.where(purge_eligible_at: ..now).in_batches(of: batch_size) do |batch|
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
    klass.where(purge_eligible_at: ..now).where(terminated_at: nil).in_batches(of: batch_size) do |batch|
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
