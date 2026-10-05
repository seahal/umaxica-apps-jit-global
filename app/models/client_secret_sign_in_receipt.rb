# frozen_string_literal: true

# Successful Ticket commit evidence; failed attempts remain SignInFlow facts.
# This record does not authorize a claim or replace the canonical login boundary.
class ClientSecretSignInReceipt < AppTicketRecord
  class InvalidCommit < StandardError; end

  belongs_to :sign_in_flow, class_name: "ClientSignInFlow"

  attr_readonly :operation_id, :credential_ref, :client_ref, :sign_in_flow_id,
                :root_token_ref, :committed_at

  before_create :verify_successful_commit!

  private

  def verify_successful_commit!
    flow = ClientSignInFlow.lock.find(sign_in_flow_id)
    token = flow.token
    claim =
      AppZenithRecord.connected_to(role: :writing) do
        ClientSecretCredential.find_by(public_id: credential_ref, claim_operation_id: operation_id)
      end
    ceremony = claim && ClientAuthCeremonySession.lock.find_by(id: claim.claim_ceremony_session_id)
    unless flow.sign_in_completed? && flow.authentication_method == "secret" &&
        flow.authentication_context == "normal" && flow.completed_at.present? &&
        flow.session_issued_at == committed_at && token.present? &&
        token.public_id == root_token_ref && token.user_id == flow.principal_id &&
        token.root_login_established_at == committed_at && token.user.public_id == client_ref &&
        matching_claim?(claim, flow) && ceremony &&
        ceremony.authentication_method == "secret" && matching_ceremony?(ceremony, flow, claim)
      raise InvalidCommit, "receipt requires matching normal Secret root login commit facts"
    end
  end

  def matching_claim?(claim, flow)
    claim && claim.client_id == flow.principal_id && claim.client.public_id == client_ref &&
      claim.claim_sign_in_flow_ref == flow.public_id && claim.claimed_at &&
      claim.discard_at == Float::INFINITY && claim.consumed_at.nil?
  end

  def matching_ceremony?(ceremony, flow, claim)
    now = ClientSignInFlow.database_now
    if ceremony.admission_purpose == "local_sign_in"
      return ceremony.local_sign_in_flow_ref == flow.public_id && ceremony.active?(now: now)
    end
    return false unless ceremony.admission_purpose == "authentication_handoff" && ceremony.completed? &&
      ceremony.admitted? && ceremony.revoked_at.nil? && ceremony.cancelled_at.nil? && ceremony.expires_at > now

    transaction = ClientOidcAuthorizationTransaction.find_by(
      transaction_id: ceremony.authorization_transaction_ref, secret_sign_in_flow_id: flow.id,
    )
    transaction&.authenticated? && transaction.auth_method == "passcode" &&
      transaction.actor_ref == claim.client.public_id && !transaction.expired?(now: now) &&
      !transaction.login_challenge_expired?(now: now)
  end
end
