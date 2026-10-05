# frozen_string_literal: true

class ClientSecretLifecycleJob < ApplicationJob
  queue_as :retention

  public

  def perform(batch_size: 500)
    unless batch_size.is_a?(Integer) && batch_size.between?(1, 500)
      raise ArgumentError, "Secret lifecycle batch must be between one and five hundred"
    end
    return if FeatureFlags.enabled?(:retention_purge_suspended)

    delay = ClientSecretLifetimesValue.purge_delay
    AppZenithRecord.connected_to(role: :writing) do
      now = Client.database_now
      ClientSecretIssuance.where(confirmed_at: nil, canceled_at: nil).where(expires_at: ..now)
        .where(discard_at: Float::INFINITY).order(:id).limit(batch_size).each do |issuance|
        ClientSecretIssuanceExpiryInvalidator.call!(issuance: issuance, executor_job_id: job_id, purge_after: delay)
      end
      reconcile_signup_batches!(batch_size, delay)
      ClientSecretCredential.where.not(claimed_at: nil).where(discard_at: Float::INFINITY)
        .order(:id).limit(batch_size).each do |credential|
        ClientSecretClaimFinalizer.call!(credential: credential, purge_after: delay)
      end
      ClientSecretAuditDeliveryJob.perform_now(
        batch_size: batch_size, retention_seconds: ClientSecretLifetimesValue.outbox_retention.to_i,
      )
      ClientSecretCredential.where(purge_eligible_at: ..now).order(:id).limit(batch_size).each do |credential|
        ClientSecretCredentialPurger.call!(credential: credential, executor_job_id: job_id)
      end
      ClientSecretIssuance.where(confirmed_at: nil).where(purge_eligible_at: ..now)
        .order(:id).limit(batch_size).each do |issuance|
        ClientSecretIssuancePurger.call!(issuance: issuance, executor_job_id: job_id)
      end
      reconcile_completed_receipts!(batch_size)
      ClientSecretAuditOutboxPurgeJob.perform_now(batch_size: batch_size)
    end
  end

  private

  def reconcile_completed_receipts!(batch_size)
    AppTicketRecord.connected_to(role: :writing) do
      now = ClientSignInFlow.database_now
      receipts = ClientSecretSignInReceipt.joins(:sign_in_flow)
        .where(client_sign_in_flows: { expires_at: ..now }).order(:id).limit(batch_size)
      return unless receipts.exists?

      duration = ClientSecretLifetimesValue.proof_retention
      receipts.each { |receipt| ClientSecretSignInReceiptPurger.call!(receipt: receipt, retention_after: duration) }
    end
  end

  def reconcile_signup_batches!(batch_size, delay)
    terminal_signup_states = %w(CANCELLED EXPIRED FAILED).freeze
    ClientSecretIssuance.where.not(sign_up_flow_ref: nil).where(signup_completed_at: nil)
      .where(discard_at: Float::INFINITY).order(:id).limit(batch_size).each do |issuance|
      AppTicketRecord.connected_to(role: :writing) do
        flow = ClientSignUpFlow.find_by(public_id: issuance.sign_up_flow_ref, principal_id: issuance.client_id)
        if flow&.sign_up_completed?
          ClientSecretPasskeyReservationIssuer.complete_sign_up!(flow: flow)
        elsif flow && terminal_signup_states.include?(ClientSignUpFlow::STATUS_NAMES.fetch(flow.status_id))
          ClientSecretPasskeyReservationIssuer.terminate_sign_up!(flow: flow, purge_after: delay)
        end
      end
    end
  end
end
