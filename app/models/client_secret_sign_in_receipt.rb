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
    unless flow.sign_in_completed? && flow.authentication_method == "secret" &&
        flow.authentication_context == "normal" && flow.completed_at.present? &&
        flow.session_issued_at == committed_at && token.present? &&
        token.public_id == root_token_ref && token.user_id == flow.principal_id &&
        token.root_login_established_at == committed_at && token.user.public_id == client_ref
      raise InvalidCommit, "receipt requires matching normal Secret root login commit facts"
    end
  end
end
