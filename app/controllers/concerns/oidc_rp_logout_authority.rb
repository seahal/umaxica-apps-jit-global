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
    origin_proof_state = session[AcmeLogoutTransactionable::BROWSER_RP_LOGOUT_PROOFS_SESSION_KEY]
    origin_proof_state = origin_proof_state.dup if origin_proof_state.is_a?(Hash)
    transaction = browser_rp_logout_transaction
    return render_browser_rp_logout_rejected! unless transaction

    current_transaction = transaction
    @logout_transaction = current_transaction
    if current_transaction.expected_step == AcmeLogoutTransaction::STEP_AUTHORITY_REVOKED
      session_record = find_browser_rp_logout_session(current_transaction)
      return render_browser_rp_logout_rejected! unless session_record

      # The durable challenge identifies the intended parent but does not authenticate the
      # confirmation. A missing or different current IdP session is the REQ-009 error stop: keep
      # the transaction and every session unchanged, and do not redirect to the origin.
      unless browser_rp_logout_authority_matches?(current_transaction, session_record)
        return render_oidc_end_session_session_missing_error
      end

      current_transaction = revoke_browser_rp_authority!(current_transaction, session_record)
    end

    if current_transaction.expected_step == AcmeLogoutTransaction::STEP_AUTHORITY_CLEANUP_ISSUED
      clear_base_authority_cookies!
      current_transaction = advance_browser_rp_logout!(
        current_transaction,
        AcmeLogoutTransaction::STEP_AUTHORITY_CLEANUP_ISSUED,
      )
    end

    redirect_to(browser_rp_logout_origin_url(current_transaction), allow_other_host: true, status: :see_other)
  rescue AuthenticationLogoutCurrentSession::CommitOutcomeUnknown => e
    warn_sign_out_event(
      "auth.sign_out.commit_outcome_indeterminate",
      transaction: @logout_transaction,
      cleanup_performed: false,
      result: "indeterminate",
      error_class: e.class.name,
    )
    render_sign_out_indeterminate!
  rescue AuthenticationLogoutCurrentSession::PreconditionFailed
    # The authority or binding changed between the first check and the parent lock. Nothing was
    # revoked; this is the same REQ-009 error stop as a missing or different IdP session.
    render_oidc_end_session_session_missing_error
  rescue ActiveRecord::ActiveRecordError, RpSession::IssuanceRejected => e
    render_browser_rp_logout_failure!(e)
  ensure
    if origin_proof_state.is_a?(Hash) && origin_proof_state.present?
      session[AcmeLogoutTransactionable::BROWSER_RP_LOGOUT_PROOFS_SESSION_KEY] = origin_proof_state
    end
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

  def revoke_browser_rp_authority!(transaction, session_record)
    root_token = session_record.parent_token
    raise RpSession::IssuanceRejected, "Browser Session current root token is missing" unless root_token

    AuthenticationLogoutCurrentSession.call(
      resource: browser_rp_logout_resource(session_record),
      token: root_token,
      token_class: root_token.class,
      session_public_id: root_token.public_id,
      reason: "rp_initiated_logout",
      precondition: -> { browser_rp_logout_authority_still_matches?(transaction) },
    )
    advance_browser_rp_logout!(transaction, AcmeLogoutTransaction::STEP_AUTHORITY_REVOKED)
  end

  def browser_rp_logout_authority_still_matches?(transaction)
    fresh_session_record = find_browser_rp_logout_session(transaction)
    fresh_session_record.present? && browser_rp_logout_authority_matches?(transaction, fresh_session_record)
  end

  def browser_rp_logout_authority_matches?(transaction, session_record)
    target_resource = browser_rp_logout_resource(session_record)
    return false unless transaction.actor_ref == target_resource.public_id
    return false unless browser_rp_logout_binding_matches?(transaction, session_record)

    authority_resource = current_resource
    resource_matches = authority_resource&.class == target_resource.class && authority_resource.id == target_resource.id
    return false unless resource_matches

    authority_token = current_session
    target_root_token = session_record.parent_token
    return false unless authority_token && target_root_token && authority_token.class == target_root_token.class

    authority_token.device_session_id.present? && authority_token.device_session_id == session_record.device_session_id
  end

  def browser_rp_logout_binding_matches?(transaction, session_record)
    return false unless transaction.browser_rp_binding_v1?

    expected_realm =
      case session_record
      when ClientRpSession then "app"
      when VisitorRpSession then "com"
      when OperatorRpSession then "org"
      else return false
      end
    return false unless transaction.realm == expected_realm

    device_session = session_record.parent_device_session
    root_token = session_record.parent_token
    return false unless device_session && root_token
    return false unless transaction.parent_session_ref == device_session.public_id

    current_family = root_token.refresh_token_family_id.presence || device_session.refresh_token_family_id.presence
    return false unless current_family.present? && transaction.root_refresh_family_ref == current_family

    generation = root_token.refresh_token_generation
    generation.is_a?(Integer) && generation >= transaction.captured_root_generation.to_i
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
        ClientRpSession.includes(client_device_session: :user).find_by(
          public_id: transaction.session_ref,
          oidc_client_id: client.client_id,
        )
      end
    when "visitor"
      ComTicketRecord.connected_to(role: :writing) do
        VisitorRpSession.includes(visitor_device_session: :visitor).find_by(
          public_id: transaction.session_ref,
          oidc_client_id: client.client_id,
        )
      end
    when "operator"
      OrgTicketRecord.connected_to(role: :writing) do
        OperatorRpSession.includes(operator_device_session: :staff).find_by(
          public_id: transaction.session_ref,
          oidc_client_id: client.client_id,
        )
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

  # REQ-003: the parent COMMIT and the AppTicket progress are separate facts. When anything fails
  # after the parent was revoked, the IdP still shows the global result with the origin cleanup
  # incomplete instead of hiding it behind a rejection; when the parent cannot be read the result
  # is indeterminate. A failure before COMMIT keeps the existing rejection.
  def render_browser_rp_logout_failure!(error)
    parent_state = browser_rp_logout_parent_state
    return render_sign_out_indeterminate! if parent_state == :unreadable

    unless parent_state == :revoked
      raise error unless error.is_a?(ActiveRecord::RecordNotFound) || error.is_a?(ActiveRecord::RecordInvalid) ||
        error.is_a?(RpSession::IssuanceRejected)

      return render_browser_rp_logout_rejected!
    end

    warn_sign_out_event(
      "auth.sign_out.authority_progress_failed",
      transaction: @logout_transaction,
      cleanup_performed: false,
      result: "global_cleanup_incomplete",
      error_class: error.class.name,
    )
    clear_base_authority_cookies!
    response.set_header("Cache-Control", "no-store")
    @sign_out_cleanup_incomplete = true
    @render_surface_erb_layout = true
    render "auth/shared/sign_outs/complete", status: :ok
  end

  def browser_rp_logout_parent_state
    return :unknown_transaction if @logout_transaction.blank?

    AcmeLogoutTransactionCoordinator.parent_revoked?(@logout_transaction) ? :revoked : :active
  rescue ActiveRecord::ActiveRecordError
    :unreadable
  end

  def render_browser_rp_logout_rejected!
    response.set_header("Cache-Control", "no-store")
    head :not_found
  end
end
