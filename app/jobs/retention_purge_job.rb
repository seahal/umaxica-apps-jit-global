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
require "digest"

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

      if klass == ClientToken
        purge_client_tokens(klass, now: now, batch_size: limit)
        next
      end

      if klass == ClientPasskey
        purge_client_passkeys(klass, now: now, batch_size: limit)
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
      batch.to_a.each do |flow|
        owner = Client.find_by(id: flow.principal_id)
        if owner
          owner.with_lock do
            AppTicketRecord.connected_to(role: :writing) do
              klass.transaction do
                current = klass.lock.find_by(id: flow.id, public_id: flow.public_id)
                next unless current
                next if client_sign_up_flow_protected?(current)

                klass.where(id: current.id).delete_all
              end
            end
          end
        elsif !client_sign_up_flow_source_hold?(flow)
          klass.where(id: flow.id).delete_all
        end
      end
    end
  end

  def purge_client_tokens(klass, now:, batch_size:)
    klass.where(purge_eligible_at: ..now).in_batches(of: batch_size) do |batch|
      batch.to_a.each do |token|
        owner = Client.find_by(id: token.user_id)
        if owner
          owner.with_lock do
            AppTicketRecord.connected_to(role: :writing) do
              klass.transaction do
                current = klass.lock.find_by(id: token.id, public_id: token.public_id)
                next unless current
                next if client_token_source_hold?(current, owner)

                klass.where(id: current.id).delete_all
              end
            end
          end
        elsif !client_token_source_hold?(token)
          klass.where(id: token.id).delete_all
        end
      end
    end
  end

  def purge_client_passkeys(klass, now:, batch_size:)
    klass.where(purge_eligible_at: ..now).in_batches(of: batch_size) do |batch|
      batch.to_a.each do |passkey|
        owner = Client.find_by(id: passkey.user_id)
        if owner
          owner.with_lock do
            AppTicketRecord.connected_to(role: :writing) do
              ClientSignUpFlow.transaction do
                next if ClientSignUpFlow.lock.exists?(pending_passkey_registration_id: passkey.id)

                AppZenithRecord.connected_to(role: :writing) do
                  klass.transaction do
                    current = klass.lock.find_by(id: passkey.id, public_id: passkey.public_id)
                    next unless current
                    next if client_passkey_source_hold?(current, owner)

                    klass.where(id: current.id).delete_all
                  end
                end
              end
            end
          end
        elsif !client_passkey_source_hold?(passkey)
          klass.where(id: passkey.id).delete_all
        end
      end
    end
  end

  def client_sign_up_flow_protected?(flow)
    ClientSecretIssuance.exists?(
      sign_up_flow_ref: flow.public_id,
      client_id: flow.principal_id,
    ) || client_sign_up_flow_source_hold?(flow)
  end

  def client_sign_up_flow_source_hold?(flow)
    AppZenithRecord.connected_to(role: :writing) do
      ClientSecretAuditOutbox.exists?(
        event_name: "secret.issuance_purged", issuance_sign_up_flow_ref: flow.public_id,
      ) || ClientSecretIssuance.exists?(sign_up_flow_ref: flow.public_id, client_id: flow.principal_id)
    end
  end

  def client_token_source_hold?(token, owner = nil)
    client_ref = owner&.public_id
    AppZenithRecord.connected_to(role: :writing) do
      live = ClientSecretIssuance.where(browser_session_ref: token.public_id)
      live = live.where(client_id: owner.id) if owner
      purged = ClientSecretAuditOutbox.where(
        event_name: "secret.issuance_purged", issuance_browser_session_ref: token.public_id,
      )
      purged = purged.where(client_ref:) if client_ref
      live.exists? || purged.exists?
    end
  end

  def client_passkey_source_hold?(passkey, owner = nil)
    operation = passkey_registration_operation(passkey)
    AppZenithRecord.connected_to(role: :writing) do
      issuance = ClientSecretIssuance.where(origin_operation_id: operation)
      issuance = issuance.where(client_id: owner.id) if owner
      issuance.exists? ||
        ClientSecretAuditOutbox.exists?(event_name: "secret.issuance_purged", operation_ref: operation)
    end
  end

  def passkey_registration_operation(passkey)
    hex = Digest::SHA256.hexdigest("app_secret_passkey_registration:#{passkey.public_id}")
    [hex[0, 8], hex[8, 4], hex[12, 4], hex[16, 4], hex[20, 12]].join("-")
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
