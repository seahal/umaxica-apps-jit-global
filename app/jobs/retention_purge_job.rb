# typed: false
# frozen_string_literal: true

# Periodic physical deletion of records past their `purge_eligible_at` window.
#
# The set-based `delete_all` here is the Accepted, ADR-sanctioned exception to
# the forbidden-method rule on `delete_all`: see
# `adr/retainable-concern-and-retention-purge.md` and the "ADR-sanctioned
# data-retention exceptions" section of `docs/reference/forbidden-rails-methods.md`.
# Email/Telephone instead use their separate locked history-aware purgers under
# `adr/realm-separated-identifiers-and-dead-history.md`; other batch deletion stays set-based.
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

    failures = []
    RETAINABLE_MODELS.each do |klass|
      purge_retained_model(klass, batch_size: limit)
    rescue StandardError => e
      failures << e
      Rails.error.report(
        e,
        handled: false,
        context: { job: self.class.name, retained_model: klass.name, batch_size: limit },
      )
    end

    raise failures.first if failures.any?
  end

  private

  def purge_retained_model(klass, batch_size:)
    now = klass.database_now
    return if klass == ClientSecretCredential
    return if purge_special_retained_model(klass, now: now, batch_size: batch_size)
    return unless klass.column_names.include?("purge_eligible_at")

    klass.where(purge_eligible_at: ..now).in_batches(of: batch_size).delete_all
  end

  def purge_special_retained_model(klass, now:, batch_size:)
    if [ClientEmail, VisitorEmail].include?(klass)
      purge_email_identifiers(klass, now: now, batch_size: batch_size)
    elsif [ClientTelephone, VisitorTelephone].include?(klass)
      purge_telephone_identifiers(klass, now: now, batch_size: batch_size)
    elsif klass == Avatar
      purge_avatars(now: now, batch_size: batch_size)
    elsif [Client, Visitor].include?(klass)
      anonymize_accounts(klass, now: now, batch_size: batch_size)
    elsif klass == Operator
      purge_operators(now: now, batch_size: batch_size)
    elsif [ClientSignInFlow, VisitorSignInFlow, OperatorSignInFlow].include?(klass)
      purge_sign_in_flows(klass, now: now, batch_size: batch_size)
    elsif klass == ClientSignUpFlow
      purge_client_authentication_flows(klass, now: now, batch_size: batch_size)
    elsif klass == ClientToken
      purge_client_tokens(klass, now: now, batch_size: batch_size)
    elsif [ClientPasskey, VisitorPasskey].include?(klass)
      purge_passkeys(klass, now: now, batch_size: batch_size)
    elsif [ClientSessionLimitResolutionTransaction, VisitorSessionLimitResolutionTransaction,
           OperatorSessionLimitResolutionTransaction,].include?(klass)
      purge_session_limit_resolutions(klass, now: now, batch_size: batch_size)
    else
      return false
    end
    true
  end

  def purge_email_identifiers(klass, now:, batch_size:)
    klass.where(purge_eligible_at: ..now).in_batches(of: batch_size) do |batch|
      batch.each { |email| EmailIdentifierPurger.call(record: email) }
    end
  end

  def purge_telephone_identifiers(klass, now:, batch_size:)
    klass.where(purge_eligible_at: ..now).in_batches(of: batch_size) do |batch|
      batch.each { |telephone| TelephoneIdentifierPurger.call(record: telephone) }
    end
  end

  def purge_avatars(now:, batch_size:)
    Avatar.where(purge_eligible_at: ..now).in_batches(of: batch_size) do |batch|
      batch.each do |candidate|
        AvatarRecord.transaction do
          avatar = Avatar.lock.find_by(id: candidate.id)
          next unless avatar

          reason =
            if avatar.enterprise_ownership_periods.exists? || avatar.bureau_ownership_periods.exists?
              "ownership_history"
            else
              "retention_policy_pending"
            end
          AvatarPurgeDeferral.record!(avatar: avatar, reason_code: reason)
        end
      end
    end
  end

  def purge_client_authentication_flows(klass, now:, batch_size:)
    klass.where(purge_eligible_at: ..now).in_batches(of: batch_size) do |batch|
      batch.to_a.each do |flow|
        owner = Client.find_by(id: flow.principal_id)
        if owner
          owner.with_lock do
            OpBaseAppRecord.connected_to(role: :writing) do
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
            OpBaseAppRecord.connected_to(role: :writing) do
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

  def purge_passkeys(klass, now:, batch_size:)
    owner_class, owner_key, signup_flow_class, surface =
      if klass == ClientPasskey
        [Client, :user_id, ClientSignUpFlow, "app"]
      elsif klass == VisitorPasskey
        [Visitor, :visitor_id, VisitorSignUpFlow, "com"]
      else
        raise ArgumentError, "unsupported passkey class: #{klass.name}"
      end

    klass.where(purge_eligible_at: ..now).in_batches(of: batch_size) do |batch|
      batch.to_a.each do |passkey|
        owner = owner_class.find_by(id: passkey.public_send(owner_key))
        if owner
          owner.with_lock do
            signup_flow_class.connection_class_for_self.connected_to(role: :writing) do
              signup_flow_class.transaction do
                next if signup_flow_class.lock.exists?(pending_passkey_registration_id: passkey.id)

                klass.connection_class_for_self.connected_to(role: :writing) do
                  klass.transaction do
                    current = klass.lock.find_by(id: passkey.id, public_id: passkey.public_id)
                    next unless current
                    next if passkey_source_hold?(klass, current, owner)

                    record_passkey_purge!(current, surface: surface)
                  end
                end
              end
            end
          end
        else
          klass.connection_class_for_self.connected_to(role: :writing) do
            klass.transaction do
              current = klass.lock.find_by(id: passkey.id, public_id: passkey.public_id)
              next unless current
              next if passkey_source_hold?(klass, current)

              record_passkey_purge!(current, surface: surface)
            end
          end
        end
      end
    end
  end

  def record_passkey_purge!(passkey, surface:)
    PasskeyAuditOutbox.record_for!(
      passkey: passkey,
      event_type: "passkey.purged",
      surface: surface,
      actor_ref: nil,
      operation_ref: "retention:#{passkey.class.name}:#{passkey.public_id}",
      occurred_at: passkey.class.database_now,
      metadata: { reason: "retention_purge" },
    )
    passkey.destroy!
  end

  def passkey_source_hold?(klass, passkey, owner = nil)
    return client_passkey_source_hold?(passkey, owner) if klass == ClientPasskey

    false
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
          next if klass == ClientSignInFlow &&
            ClientOidcAuthorizationTransaction.exists?(secret_sign_in_flow_id: flow.id)

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

  # Cross-DB cleanup cannot be rolled back with Zenith. Its idempotent deletes precede
  # the local commit so a partial failure retains the operator for the next retry.
  def purge_operators(now:, batch_size:)
    Operator.where(purge_eligible_at: ..now).in_batches(of: batch_size) do |batch|
      batch.find_each do |candidate|
        Operator.transaction do
          operator = Operator.lock.find_by(id: candidate.id)
          next unless operator

          decision_time = Operator.database_now
          next unless operator.lapsed?(decision_time) && operator.purgeable?(decision_time)
          next if enforcement_blocks_purge?(operator)

          RetentionCrossDatabaseChildPurge.call(actor: operator)
          operator.staff_emails.order(:id).find_each { |email| EmailIdentifierPurger.call(record: email) }
          operator.staff_telephones.order(:id).find_each do |telephone|
            TelephoneIdentifierPurger.call(record: telephone)
          end
          OperatorEmailHistory.where(staff_id: operator.id).delete_all
          OperatorTelephoneHistory.where(staff_id: operator.id).delete_all
          Operator.where(id: operator.id).delete_all
        end
      end
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
        retired =
          actor.with_lock do
            decision_time = klass.database_now
            next false if actor.terminated_at || !actor.lapsed?(decision_time) || !actor.purgeable?(decision_time)

            if active_retention_hold_for(actor, now: decision_time)
              handle_actor_purge_skipped_by_hold(actor, now: decision_time)
              next false
            end
            if enforcement_blocks_purge?(actor)
              WithdrawalOccurrenceRecording.record!(
                subject: actor,
                event_type: "withdrawal.purge_skipped_by_enforcement",
              )
              next false
            end

            RetentionCrossDatabaseChildPurge.call(actor: actor)
            WithdrawalPersonalDataAnonymizer.call(actor: actor)
            next false unless collect_actor_identifiers(actor)

            actor.update!(withdrawn_at: decision_time, terminated_at: decision_time)
            true
          end
        next unless retired

        WithdrawalOccurrenceRecording.record!(subject: actor, event_type: "withdrawal.purged")
        WithdrawalOccurrenceRecording.record!(subject: actor, event_type: "withdrawal.shredded")
      end
    end
  end

  def collect_actor_identifiers(actor)
    emails, telephones =
      case actor
      when Client then [actor.client_emails, actor.client_telephones]
      when Visitor then [actor.visitor_emails, actor.visitor_telephones]
      else raise ArgumentError, "unsupported identifier retirement actor"
      end
    emails.where(purge_eligible_at: ..emails.klass.database_now).order(:id).find_each do |email|
      EmailIdentifierPurger.call(record: email)
    end
    telephones.where(purge_eligible_at: ..telephones.klass.database_now).order(:id).find_each do |telephone|
      TelephoneIdentifierPurger.call(record: telephone)
    end

    remaining = emails.exists? || telephones.exists?
    if remaining
      WithdrawalOccurrenceRecording.record!(
        subject: actor,
        event_type: "withdrawal.purge_deferred",
        context: { reason_code: "identifier_retention" },
      )
    end
    !remaining
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
