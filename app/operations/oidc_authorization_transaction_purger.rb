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

  SESSION_LIMIT_RESOLUTION_MODELS = {
    ClientOidcAuthorizationTransaction => [ClientSessionLimitResolutionTransaction, ClientSignInFlow],
    VisitorOidcAuthorizationTransaction => [VisitorSessionLimitResolutionTransaction, VisitorSignInFlow],
    OperatorOidcAuthorizationTransaction => [OperatorSessionLimitResolutionTransaction, OperatorSignInFlow],
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
        rows.each do |row|
          next if protected_ids.include?(row.id)
          next unless purge_session_limit_resolutions_for!(row, ClientOidcAuthorizationTransaction)
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
          next unless purge_session_limit_resolutions_for!(row, model)
          next unless AuthAdmissionBindingPurger.purge_for_parent!(
            parent: row, now:, retention_period:,
          )

          deleted += model.where(id: row.id).delete_all
        end
      end
    end
    deleted
  end

  # Session-limit resolution rows are terminal audit facts, but their parent
  # authorization transaction has a restrictive FK. The resolution is
  # collected at the same parent-retention boundary, after open resolutions and
  # RESOLVED continuations that still lack a root token have been held. This
  # keeps child-before-parent ordering explicit without treating a terminal
  # resolution as an indefinite parent hold.
  def purge_session_limit_resolutions_for!(parent, authorization_model)
    resolution_model, flow_model = SESSION_LIMIT_RESOLUTION_MODELS.fetch(authorization_model)
    resolutions = resolution_model.where(oidc_authorization_transaction_id: parent.id).lock.to_a
    return true if resolutions.empty?

    flow_ids = resolutions.map(&:sign_in_flow_id).uniq
    flows = flow_model.where(id: flow_ids).index_by(&:id)
    return false if resolutions.any? do |resolution|
      flow = flows[resolution.sign_in_flow_id]
      !flow || !resolution.state_id.in?(resolution_model::TERMINAL_STATES) ||
        (resolution.state_id == resolution_model::RESOLVED && flow.token_id.nil?)
    end

    resolution_model.where(id: resolutions.map(&:id)).delete_all
    true
  end
end
