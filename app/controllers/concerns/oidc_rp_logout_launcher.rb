# typed: false
# frozen_string_literal: true

module OidcRpLogoutLauncher
  extend ActiveSupport::Concern

  included do
    prepend_before_action :normalize_rp_logout_region!, if: -> { action_name == "create" }
    ensure_fqdn_gate_first!
  end

  public

  def authenticate_oidc_rp_session!
    resolved = resolve_oidc_rp_logout_credentials
    unless resolved
      render plain: "Authentication required", status: :unauthorized
      return
    end

    @oidc_rp_logout_session, @oidc_rp_logout_resource, @oidc_rp_logout_access_payload = resolved
    @current_resource = @oidc_rp_logout_resource
    @current_session_public_id = @oidc_rp_logout_session.public_id
  end

  private

  def launch_oidc_rp_logout!(client_id:, issuer_resource_type:, token_issuer:, session_authority:)
    @oidc_rp_logout_session_authority = session_authority
    completion_region = rp_logout_region
    transaction_options = {
      origin_surface: logout_origin_surface,
      initiating_client_id: client_id,
      completion_url: AcmeLogoutTransactionCoordinator.completion_url_for(
        origin_surface: logout_origin_surface,
        ri: completion_region,
        surface: logout_surface_name,
      ),
      actor_ref: logout_authority_resource.try(:public_id),
      session_ref: logout_authority_session_public_id,
      callback_state: nil,
      surface: logout_surface_name,
    }
    transaction_options[:ri] = completion_region if logout_surface_name == "app"

    transaction_result = AcmeLogoutTransactionCoordinator.issue!(**transaction_options)
    return render_oidc_rp_logout_unavailable unless transaction_result.success?

    transaction = transaction_result.transaction
    log_sign_out_event(
      "auth.sign_out.transaction.issued",
      transaction: transaction,
      user_confirmation_required: true,
      auto_handoff: false,
      cleanup_performed: false,
      result: "issued",
    )

    handoff_oidc_rp_logout!(
      transaction,
      client_id: client_id,
      issuer_resource_type: issuer_resource_type,
      token_issuer: token_issuer,
      completion_region: completion_region,
    )
  end

  def handoff_oidc_rp_logout!(transaction, client_id:, issuer_resource_type:, token_issuer:, completion_region:)
    state = SecureRandom.hex(16)
    id_token_hint = oidc_rp_logout_id_token_hint(
      client_id: client_id,
      issuer_resource_type: issuer_resource_type,
      token_issuer: token_issuer,
    )
    prepare_sign_out_completion_notice!(state: state)
    log_sign_out_event("auth.sign_out.step.started", transaction: transaction, result: "started")
    logout_authority_session!
    log_sign_out_event(
      "auth.sign_out.step.cleaned",
      transaction: transaction,
      cleanup_performed: true,
      result: "cleaned",
    )
    issue_sign_out_notice!
    AcmeLogoutTransactionCoordinator.advance!(logout_challenge: transaction.logout_challenge, step: "origin_cleared")
    log_sign_out_event(
      "auth.sign_out.step.advanced",
      transaction: transaction.reload,
      step_after: transaction.expected_step,
      cleanup_performed: true,
      redirect_target_surface: "acme",
      result: "advanced",
    )

    render_cross_origin_sign_out_handoff(
      target_url: acme_oidc_logout_url(
        ri: completion_region,
        id_token_hint: id_token_hint,
        post_logout_redirect_uri: AcmeLogoutTransactionCoordinator.completion_url_for(
          origin_surface: logout_origin_surface,
          ri: completion_region,
          surface: logout_surface_name,
        ),
        state: state,
        logout_challenge: transaction.logout_challenge,
        protocol: "https",
      ),
      transaction: transaction,
    )
  end

  def complete_oidc_rp_logout!
    return head(:not_found) if sign_out_active_context_present?

    notice_id = session[SignOutNotice::SIGN_OUT_NOTICE_SESSION_KEY]
    return head(:not_found) unless notice_id.is_a?(String) && notice_id.present?

    completion_state = Valkey::AuthState::SignOutNoticeStore.new.read(raw_id: notice_id)
    return head(:not_found) unless completion_state
    return head(:not_found) unless completion_state["face"].to_s == logout_surface_name.to_s

    expected_state = completion_state["state"].to_s
    provided_state = params[:state].to_s
    return head(:not_found) if expected_state.present? && provided_state.blank?
    return head(:not_found) if expected_state.blank? && provided_state.present?
    return head(:not_found) unless expected_state.blank? || expected_state.length == provided_state.length
    return head(:not_found) if expected_state.present? && !ActiveSupport::SecurityUtils.secure_compare(
      expected_state,
      provided_state,
    )

    @sign_out_notice = consume_sign_out_notice
    return head(:not_found) unless @sign_out_notice

    render_oidc_rp_logout_completion
  end

  def oidc_rp_logout_id_token_hint(client_id:, issuer_resource_type:, token_issuer:)
    OidcIdTokenIssuer.call(
      resource: logout_authority_resource,
      client: OidcClientRegistry.find!(client_id),
      nonce: "sign-out",
      issuer: OidcIssuer.for_resource_type(issuer_resource_type),
      jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_resource_type(issuer_resource_type),
      subject: OidcSubject.for(logout_authority_resource, resource_type: token_issuer),
      sid: logout_authority_session_public_id,
    )
  end

  def logout_current_rp_session!
    result = RpSessionRevoker.call(
      scope: :rp_session,
      record: oidc_rp_logout_session,
      status: "success",
    )
    raise OidcRpLogoutError, "RP Session revoke failed" unless result.success?

    record_logout_audit(oidc_rp_logout_resource)
  ensure
    rotate_preference_after_sign_out! if respond_to?(:rotate_preference_after_sign_out!, true)
    clear_oidc_rp_logout_cookies!
    clear_auth_cookies! if respond_to?(:clear_auth_cookies!, true)
    Actor.clear if defined?(Actor)
    reset_session_and_clear_inertia_history!
  end

  def logout_authority_session!
    return logout_current_rp_session! if rp_session_logout?

    logout_current_session!(reason: "user_logout")
  end

  class OidcRpLogoutError < StandardError; end

  private

  def resolve_oidc_rp_logout_credentials
    resource_type = oidc_rp_logout_resource_type
    access_plain, refresh_plain = oidc_rp_logout_cookie_values
    return if access_plain.blank? && refresh_plain.blank?

    access_payload = decode_oidc_rp_logout_access(access_plain, resource_type)
    access_session = find_oidc_rp_logout_access_session(access_payload, resource_type)
    refresh_session = find_oidc_rp_logout_session_from_refresh(
      refresh_plain,
      client_id: oidc_client_id,
      resource_type: resource_type,
    ) if refresh_plain.present?
    return unless valid_oidc_rp_logout_credential_set?(
      access_plain,
      access_payload,
      access_session,
      refresh_session,
      resource_type,
      refresh_present: refresh_plain.present?,
    )

    session_record = access_session || refresh_session
    return unless oidc_rp_logout_session_current?(session_record)

    resource = oidc_rp_logout_resource_for(session_record)
    return unless resource&.active?
    return if access_payload && OidcSubject.for(resource, resource_type: resource_type) !=
      AuthorizationTokenClaims.subject(access_payload).to_s

    [session_record, resource, access_payload]
  rescue ArgumentError, ActiveRecord::RecordNotFound, URI::InvalidURIError
    nil
  end

  def oidc_rp_logout_cookie_values
    [
      cookies[OidcRpBrowserCredentialContract::ACCESS_COOKIE].to_s.presence,
      cookies[OidcRpBrowserCredentialContract::REFRESH_COOKIE].to_s.presence,
    ]
  end

  def decode_oidc_rp_logout_access(access_plain, resource_type)
    return if access_plain.blank?

    OidcRpBrowserCredentialContract.decode_access_token(
      token: access_plain,
      host: request.host,
      resource_type: resource_type,
      client_id: oidc_client_id,
      allow_expired: true,
    )
  end

  def find_oidc_rp_logout_access_session(access_payload, resource_type)
    return if access_payload.blank?

    find_oidc_rp_logout_session(
      public_id: AuthorizationTokenClaims.session_id(access_payload),
      client_id: oidc_client_id,
      resource_type: resource_type,
    )
  end

  def valid_oidc_rp_logout_credential_set?(
    access_plain,
    access_payload,
    access_session,
    refresh_session,
    resource_type,
    refresh_present:
  )
    return false if access_plain.present? && access_payload.blank?
    return false if access_payload && !valid_oidc_rp_logout_access?(access_payload, access_session, resource_type)
    return false if refresh_session.blank? && access_session.blank? && refresh_present
    return false if access_session && refresh_session && access_session.public_id != refresh_session.public_id

    true
  end

  def oidc_rp_logout_resource_type
    OidcIssuer.resource_type_for_client(OidcClientRegistry.find!(oidc_client_id))
  end

  def oidc_rp_logout_session_class_for(resource_type)
    case resource_type.to_s
    when "operator" then OperatorRpSession
    when "visitor" then VisitorRpSession
    else ClientRpSession
    end
  end

  def oidc_rp_logout_connection_for(resource_type)
    case resource_type.to_s
    when "operator" then OrgTicketRecord
    when "visitor" then ComTicketRecord
    else AppTicketRecord
    end
  end

  def find_oidc_rp_logout_session(public_id:, client_id:, resource_type:)
    return if public_id.blank?

    oidc_rp_logout_connection_for(resource_type).connected_to(role: :writing) do
      oidc_rp_logout_session_class_for(resource_type).find_by(public_id: public_id, oidc_client_id: client_id)
    end
  end

  def find_oidc_rp_logout_session_from_refresh(refresh_plain, client_id:, resource_type:)
    parsed = oidc_rp_logout_session_class_for(resource_type).parse_refresh_token(refresh_plain)
    return if parsed.blank?

    public_id, verifier = parsed
    session_record = find_oidc_rp_logout_session(
      public_id: public_id,
      client_id: client_id,
      resource_type: resource_type,
    )
    return unless session_record&.authenticate_refresh_token(verifier)

    session_record
  end

  def valid_oidc_rp_logout_access?(payload, session_record, resource_type)
    return false unless session_record
    return false if session_record.oidc_jti.blank?

    expected_jti = session_record.oidc_jti.to_s
    actual_jti = AuthorizationTokenClaims.jti(payload).to_s
    return false unless expected_jti.bytesize == actual_jti.bytesize
    return false unless ActiveSupport::SecurityUtils.secure_compare(expected_jti, actual_jti)

    OidcSubject.for(oidc_rp_logout_resource_for(session_record), resource_type: resource_type).to_s ==
      AuthorizationTokenClaims.subject(payload).to_s
  rescue ArgumentError
    false
  end

  def oidc_rp_logout_session_current?(session_record)
    return false unless session_record
    return false if session_record.revoked?

    session_record.parent_token_active?
  end

  def oidc_rp_logout_resource_for(session_record)
    case session_record
    when OperatorRpSession then session_record.staff
    when VisitorRpSession then session_record.visitor
    else session_record.user
    end
  end

  def oidc_rp_logout_session
    @oidc_rp_logout_session || raise(OidcRpLogoutError, "RP Session was not authenticated")
  end

  def rp_session_logout?
    @oidc_rp_logout_session_authority == :rp_session
  end

  def logout_authority_resource
    return oidc_rp_logout_resource if rp_session_logout?

    current_resource
  end

  def logout_authority_session_public_id
    return oidc_rp_logout_session.public_id if rp_session_logout?

    safe_current_session_public_id_for_logout
  end

  def oidc_rp_logout_resource
    @oidc_rp_logout_resource || raise(OidcRpLogoutError, "RP resource was not authenticated")
  end

  def clear_oidc_rp_logout_cookies!
    cookies.delete(
      OidcRpBrowserCredentialContract::ACCESS_COOKIE,
      OidcRpBrowserCredentialContract.access_cookie_deletion_options,
    )
    cookies.delete(
      OidcRpBrowserCredentialContract::REFRESH_COOKIE,
      OidcRpBrowserCredentialContract.refresh_cookie_deletion_options,
    )
  end

  def acme_oidc_logout_url(**query)
    region = RequestContextContract.normalize_region(query.delete(:ri).presence || rp_logout_region)
    public_send(
      "base_#{sign_surface_name}_oidc_logout_url",
      host: oidc_base_authority_host,
      ri: region,
      **query,
    )
  end

  def oidc_base_authority_host
    case sign_surface_name
    when "app"
      ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    when "com"
      ENV.fetch("PUBLIC_BASE_CORPORATE_URL")
    when "org"
      ENV.fetch("PUBLIC_BASE_STAFF_URL")
    end
  end

  def oidc_acme_host
    oidc_base_authority_host
  end

  def render_oidc_rp_logout_unavailable
    return render_oidc_rp_logout_completion unless logout_surface_name == "app"

    render "auth/shared/sign_outs/unavailable", status: :unprocessable_content
  end

  def render_oidc_rp_logout_completion
    render "auth/shared/sign_outs/complete", status: :ok
  end

  def rp_logout_region
    RequestContextContract.normalize_region(params[:ri])
  end

  def normalize_rp_logout_region!
    return unless logout_surface_name == "app"

    params[:ri] = rp_logout_region
  end

  def sign_surface_name
    controller_path.split("/").second
  end

  def logout_origin_surface
    origin_surface = controller_path.split("/").first
    (origin_surface == "auth") ? "sign" : origin_surface
  end

  def logout_surface_name
    controller_path.split("/").second
  end
end
