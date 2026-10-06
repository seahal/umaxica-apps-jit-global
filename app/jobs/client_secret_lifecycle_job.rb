# frozen_string_literal: true

class ClientSecretLifecycleJob < ApplicationJob
  queue_as :retention

  public

  def perform(batch_size: 500, phase: nil, after_id: 0, through_id: nil)
    unless batch_size.is_a?(Integer) && batch_size.between?(1, 500) &&
        [nil, "credentials", "signup", "receipts"].include?(phase) && after_id.is_a?(Integer) && after_id >= 0 &&
        (through_id.nil? || (through_id.is_a?(Integer) && through_id >= after_id))
      raise ArgumentError, "Secret lifecycle requires a bounded batch, supported phase and ordered integer cursors"
    end
    return if FeatureFlags.enabled?(:retention_purge_suspended)

    delay = ClientSecretLifetimesValue.purge_delay
    AppZenithRecord.connected_to(role: :writing) do
      if phase == "credentials"
        reconcile_credentials!(batch_size, delay, after_id, through_id)
        return
      elsif phase == "signup"
        reconcile_signup_batches!(batch_size, delay, after_id, through_id)
        return
      elsif phase == "receipts"
        reconcile_completed_receipts!(batch_size, after_id, through_id)
        return
      elsif !phase.nil?
        raise ArgumentError, "Secret lifecycle has an unsupported continuation phase"
      end

      now = Client.database_now
      ClientSecretIssuance.where(confirmed_at: nil, canceled_at: nil).where(expires_at: ..now)
        .where(discard_at: Float::INFINITY).order(:id).limit(batch_size).each do |issuance|
        ClientSecretIssuanceExpiryInvalidator.call!(issuance: issuance, executor_job_id: job_id, purge_after: delay)
      end
      reconcile_signup_batches!(batch_size, delay, after_id, through_id)
      reconcile_credentials!(batch_size, delay, after_id, through_id)
      reconcile_completed_receipts!(batch_size, after_id, through_id)
      ClientSecretIssuanceCollectionJob.perform_now(batch_size: batch_size)
      ClientSecretAuditOutboxPurgeJob.perform_now(batch_size: batch_size)
    end
  end

  private

  def reconcile_credentials!(batch_size, delay, after_id, through_id)
    scope = ClientSecretCredential.where.not(claimed_at: nil).where(discard_at: Float::INFINITY)
      .or(ClientSecretCredential.where(purge_eligible_at: ..Client.database_now))
    through_id = scope.maximum(:id) if through_id.nil?
    rows = through_id ? scope.where(id: (after_id + 1)..through_id).order(:id).limit(batch_size).to_a : []
    rows.each do |credential|
      if credential.claimed_at && credential.discard_at == Float::INFINITY
        ClientSecretClaimFinalizer.call!(credential: credential, purge_after: delay)
      end
    end
    # Delivery is also required when the only surviving source fact is its outbox.
    ClientSecretAuditDeliveryJob.perform_now(
      batch_size: batch_size, retention_seconds: ClientSecretLifetimesValue.outbox_retention.to_i,
    )
    rows.each { |credential| ClientSecretCredentialPurger.call!(credential: credential, executor_job_id: job_id) }
    return if rows.empty? || !scope.exists?(id: (rows.last.id + 1)..through_id)

    ClientSecretLifecycleJob.perform_later(
      batch_size: batch_size, phase: "credentials", after_id: rows.last.id, through_id: through_id,
    )
  end

  def reconcile_completed_receipts!(batch_size, after_id, through_id)
    AppTicketRecord.connected_to(role: :writing) do
      now = ClientSignInFlow.database_now
      scope = ClientSecretSignInReceipt.joins(:sign_in_flow)
        .where(client_sign_in_flows: { expires_at: ..now })
      through_id = scope.maximum(:id) if through_id.nil?
      return if through_id.nil?

      receipts = scope.where(id: (after_id + 1)..through_id).order(:id).limit(batch_size).to_a
      return if receipts.empty?

      duration = ClientSecretLifetimesValue.proof_retention
      receipts.each { |receipt| ClientSecretSignInReceiptPurger.call!(receipt: receipt, retention_after: duration) }
      return unless scope.exists?(id: (receipts.last.id + 1)..through_id)

      ClientSecretLifecycleJob.perform_later(
        batch_size: batch_size, phase: "receipts", after_id: receipts.last.id, through_id: through_id,
      )
    end
  end

  def reconcile_signup_batches!(batch_size, delay, after_id, through_id)
    terminal_signup_states = %w(CANCELLED EXPIRED FAILED HALTED FINALIZED SIGN_IN_HANDOFF_PENDING).freeze
    scope = ClientSecretIssuance.where.not(sign_up_flow_ref: nil).where(signup_completed_at: nil)
      .where(discard_at: Float::INFINITY)
    through_id = scope.maximum(:id) if through_id.nil?
    return if through_id.nil?

    rows = scope.where(id: (after_id + 1)..through_id).order(:id).limit(batch_size).to_a
    rows.each do |issuance|
      AppTicketRecord.connected_to(role: :writing) do
        flow = ClientSignUpFlow.find_by(public_id: issuance.sign_up_flow_ref, principal_id: issuance.client_id)
        if flow&.sign_up_completed?
          ClientSecretPasskeyReservationIssuer.complete_sign_up!(flow: flow)
        elsif flow && terminal_signup_states.include?(ClientSignUpFlow::STATUS_NAMES.fetch(flow.status_id))
          ClientSecretPasskeyReservationIssuer.terminate_sign_up!(flow: flow, purge_after: delay)
        end
      end
    end
    return if rows.empty? || !scope.exists?(id: (rows.last.id + 1)..through_id)

    ClientSecretLifecycleJob.perform_later(
      batch_size: batch_size, phase: "signup", after_id: rows.last.id, through_id: through_id,
    )
  end
end
