# typed: false
# frozen_string_literal: true

# Deletes authorization transactions whose expiry is at least RETENTION_PERIOD in the past.
# App Secret claims and receipts still need expired authorization facts for terminal
# reconciliation, so their dependencies remain until the corresponding proofs are collected.
class OidcAuthorizationTransactionPurger
  MODELS = {
    "app" => ClientOidcAuthorizationTransaction,
    "com" => VisitorOidcAuthorizationTransaction,
    "org" => OperatorOidcAuthorizationTransaction,
  }.freeze

  class << self
    public

    def call(now: Time.current, retention_period: OidcAuthorizationTransactionable::RETENTION_PERIOD)
      new(now: now, retention_period: retention_period).call
    end
  end

  public

  def initialize(now: Time.current, retention_period: OidcAuthorizationTransactionable::RETENTION_PERIOD)
    @now = now
    @retention_period = retention_period
  end

  def call
    MODELS.transform_values do |model|
      model.connection_owner.connected_to(role: :writing) do
        candidates = model.purgeable_at(now, retention_period: retention_period)
        (model == ClientOidcAuthorizationTransaction) ? purge_app_transactions(candidates) : purge_transactions(
          candidates, model,
        )
      end
    end
  end

  private

  attr_reader :now, :retention_period

  def purge_app_transactions(candidates)
    deleted = 0
    candidates.in_batches(of: 500) do |batch|
      ClientOidcAuthorizationTransaction.transaction do
        rows = batch.lock.to_a
        flow_ids = rows.filter_map(&:secret_sign_in_flow_id)
        flows = ClientSignInFlow.where(id: flow_ids).pluck(:id, :public_id).to_h
        claimed_refs =
          AppZenithRecord.connected_to(role: :writing) do
            ClientSecretCredential.where(claim_sign_in_flow_ref: flows.values).pluck(:claim_sign_in_flow_ref)
          end
        protected_flows = flows.filter_map { |id, reference| id if claimed_refs.include?(reference) } +
          ClientSecretSignInReceipt.where(sign_in_flow_id: flow_ids).pluck(:sign_in_flow_id)
        protected_ids = rows.filter_map { |row| row.id if protected_flows.include?(row.secret_sign_in_flow_id) }
        protected_ids += ClientSessionLimitResolutionTransaction
          .joins(:sign_in_flow)
          .where(oidc_authorization_transaction_id: rows.map(&:id))
          .where(
            "client_session_limit_resolution_transactions.state_id IN (10, 20) OR " \
            "(client_session_limit_resolution_transactions.state_id = 100 AND client_sign_in_flows.token_id IS NULL)",
          )
          .pluck(:oidc_authorization_transaction_id)
        rows.each do |row|
          next if protected_ids.include?(row.id)
          next unless AuthAdmissionBindingPurger.purge_for_parent!(
            parent: row, now:, retention_period:,
          )

          deleted += ClientOidcAuthorizationTransaction.where(id: row.id).delete_all
        end
      end
    end
    deleted
  end

  def purge_transactions(candidates, model)
    deleted = 0
    candidates.in_batches(of: 500) do |batch|
      model.transaction do
        batch.lock.to_a.each do |row|
          next unless AuthAdmissionBindingPurger.purge_for_parent!(
            parent: row, now:, retention_period:,
          )

          deleted += model.where(id: row.id).delete_all
        end
      end
    end
    deleted
  end
end
