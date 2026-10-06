# typed: false
# frozen_string_literal: true

# The Base end-session receiver for the Browser RP graph. The challenge identifies a durable
# transaction, but it never authenticates an arbitrary authority operation: the transaction's
# registered client selects the realm and its RP Session selects the parent Browser Session.
module OidcRpLogoutAuthority
  extend ActiveSupport::Concern

  public

  def browser_rp_logout_challenge?
    challenge = params[:logout_challenge].to_s
    return false if challenge.blank?

    transaction = AcmeLogoutTransactionCoordinator.find_by!(logout_challenge: challenge)
    transaction&.browser_rp_workflow? || false
  rescue ActiveRecord::RecordNotFound, ArgumentError
    false
  end

  def show_browser_rp_logout_authority!
    transaction = browser_rp_logout_transaction
    return render_browser_rp_logout_rejected! unless transaction

    @logout_transaction = transaction
    render "auth/shared/sign_outs/browser_rp_authority", layout: false, status: :ok
  end

  def create_browser_rp_logout_authority!
    transaction = browser_rp_logout_transaction
    return render_browser_rp_logout_rejected! unless transaction

    current_transaction = transaction
    @logout_transaction = current_transaction
    if current_transaction.expected_step == AcmeLogoutTransaction::STEP_AUTHORITY_REVOKED
      current_transaction = revoke_browser_rp_authority!(current_transaction)
    end

    if current_transaction.expected_step == AcmeLogoutTransaction::STEP_AUTHORITY_CLEANUP_ISSUED
      clear_base_authority_cookies!
      current_transaction = advance_browser_rp_logout!(
        current_transaction,
        AcmeLogoutTransaction::STEP_AUTHORITY_CLEANUP_ISSUED,
      )
    end

    redirect_to(browser_rp_logout_origin_url(current_transaction), allow_other_host: true, status: :see_other)
  rescue ActiveRecord::RecordNotFound, ActiveRecord::RecordInvalid, RpSession::IssuanceRejected
    render_browser_rp_logout_rejected!
  end

  private

  def browser_rp_logout_transaction
    challenge = params[:logout_challenge].to_s
    return if challenge.blank?

    transaction = AcmeLogoutTransactionCoordinator.find_by!(logout_challenge: challenge)
    return unless transaction.browser_rp_workflow?
    return unless transaction.origin_surface.in?(AcmeLogoutTransaction::BROWSER_RP_ORIGIN_SURFACES)
    return if transaction.expired? && !transaction.finalized?

    transaction
  rescue ActiveRecord::RecordNotFound, ArgumentError
    nil
  end

  def revoke_browser_rp_authority!(transaction)
    session_record = find_browser_rp_logout_session(transaction)
    raise ActiveRecord::RecordNotFound unless session_record

    root_token = session_record.parent_token
    raise RpSession::IssuanceRejected, "Browser Session current root token is missing" unless root_token

    AuthenticationLogoutCurrentSession.call(
      resource: browser_rp_logout_resource(session_record),
      token: root_token,
      token_class: root_token.class,
      session_public_id: root_token.public_id,
      reason: "rp_initiated_logout",
    )
    advance_browser_rp_logout!(transaction, AcmeLogoutTransaction::STEP_AUTHORITY_REVOKED)
  end

  def clear_base_authority_cookies!
    clear_auth_cookies! if respond_to?(:clear_auth_cookies!, true)
  end

  def advance_browser_rp_logout!(transaction, step)
    result = AcmeLogoutTransactionCoordinator.advance!(
      logout_challenge: transaction.logout_challenge,
      step: step,
    )
    raise RpSession::IssuanceRejected, result.error_description unless result.success?

    result.transaction
  end

  def find_browser_rp_logout_session(transaction)
    client = OidcClientRegistry.find!(transaction.initiating_client_id)
    resource_type = OidcIssuer.resource_type_for_client(client)
    case resource_type
    when "client"
      AppTicketRecord.connected_to(role: :writing) do
        ClientRpSession.find_by(public_id: transaction.session_ref, oidc_client_id: client.client_id)
      end
    when "visitor"
      ComTicketRecord.connected_to(role: :writing) do
        VisitorRpSession.find_by(public_id: transaction.session_ref, oidc_client_id: client.client_id)
      end
    when "operator"
      OrgTicketRecord.connected_to(role: :writing) do
        OperatorRpSession.find_by(public_id: transaction.session_ref, oidc_client_id: client.client_id)
      end
    else
      raise ArgumentError, "unsupported Browser RP logout resource type"
    end
  end

  def browser_rp_logout_resource(session_record)
    case session_record
    when ClientRpSession then session_record.user
    when VisitorRpSession then session_record.visitor
    when OperatorRpSession then session_record.staff
    else raise ArgumentError, "unsupported Browser RP Session class"
    end
  end

  def browser_rp_logout_origin_url(transaction)
    uri = URI.parse(transaction.completion_url)
    query = Rack::Utils.parse_nested_query(uri.query.to_s)
    query["logout_challenge"] = transaction.logout_challenge
    uri.query = query.to_query
    uri.to_s
  rescue URI::InvalidURIError
    raise RpSession::IssuanceRejected, "logout completion destination is invalid"
  end

  def render_browser_rp_logout_rejected!
    response.set_header("Cache-Control", "no-store")
    head :not_found
  end
end
