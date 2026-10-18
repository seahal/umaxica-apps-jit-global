# frozen_string_literal: true

# Bounded scans advance past retained allocations; periodic scans start a fresh horizon.
class ClientSecretIssuanceCollectionJob < ApplicationJob
  queue_as :retention

  public

  def perform(batch_size: 500, after_id: 0, through_id: nil)
    unless batch_size.is_a?(Integer) && batch_size.between?(1, 500) &&
        after_id.is_a?(Integer) && after_id >= 0 &&
        (through_id.nil? || (through_id.is_a?(Integer) && through_id >= after_id))
      raise ArgumentError, "Secret allocation collection requires a bounded batch and ordered integer cursors"
    end
    return if FeatureFlags.enabled?(:retention_purge_suspended)

    AppZenithRecord.connected_to(role: :writing) do
      scope = ClientSecretIssuance.all
      through_id = scope.maximum(:id) if through_id.nil?
      return if through_id.nil?

      rows = scope.where(id: (after_id + 1)..through_id).order(:id).limit(batch_size).to_a
      rows.each { |issuance| collect!(issuance) }
      return if rows.empty? || !scope.exists?(id: (rows.last.id + 1)..through_id)

      ClientSecretIssuanceCollectionJob.perform_later(
        batch_size: batch_size, after_id: rows.last.id, through_id: through_id,
      )
    end
  end

  private

  def collect!(issuance)
    if issuance.sign_up_flow_ref && issuance.signup_completed_at.nil? && issuance.discard_at != Float::INFINITY
      ClientSecretIssuancePurger.call_terminated_signup!(
        issuance: issuance, executor_job_id: job_id, retention_after: ClientSecretLifetimesValue.proof_retention,
      )
      return
    end

    case issuance.state(at: Client.database_now)
    when :confirmed
      ClientSecretIssuancePurger.call_confirmed!(
        issuance: issuance, executor_job_id: job_id, retention_after: ClientSecretLifetimesValue.proof_retention,
      )
    when :omitted
      ClientSecretIssuancePurger.call_omitted!(
        issuance: issuance, executor_job_id: job_id, retention_after: ClientSecretLifetimesValue.proof_retention,
      )
    when :expired
      ClientSecretIssuanceExpiryInvalidator.call!(
        issuance: issuance, executor_job_id: job_id, purge_after: ClientSecretLifetimesValue.purge_delay,
      )
      ClientSecretIssuancePurger.call!(issuance: issuance, executor_job_id: job_id)
    when :canceled
      ClientSecretIssuancePurger.call!(issuance: issuance, executor_job_id: job_id)
    when :pending_presentation, :pending_confirmation
      # Browser continuation is authoritative; a later periodic horizon revisits it.
      nil
    else
      raise ArgumentError, "Secret allocation has an unsupported collection state"
    end
  end
end
