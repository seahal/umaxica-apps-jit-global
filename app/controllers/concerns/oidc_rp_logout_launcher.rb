# typed: false
# frozen_string_literal: true

require "securerandom"

module OidcRpLogoutLauncher
  extend ActiveSupport::Concern

  # FIXME: Violates Umaxica/NoConcernInclusionHooks; move the declarations in this block into each class that includes this concern.
  included do
    prepend_before_action :normalize_rp_logout_region!, if: -> { action_name == "create" }
    ensure_fqdn_gate_first!
  end

  public

  def authenticate_oidc_rp_session!
    resolved = resolve_oidc_rp_logout_credentials
    unless resolved
      render plain: t("errors.messages.login_required"), status: :unauthorized
      return
    end

    @oidc_rp_logout_session, @oidc_rp_logout_resource, @oidc_rp_logout_access_payload = resolved
    @current_resource = @oidc_rp_logout_resource
    @current_session_public_id = @oidc_rp_logout_session.public_id
  rescue ActiveRecord::ActiveRecordError, PG::Error, OidcOpJwksClient::FetchError => e
    Rails.logger.error(
      "auth.sign_out.rp_local_authentication_failed error_class=#{e.class.name} result=unavailable",
    )
    render_oidc_rp_logout_unavailable(status: :service_unavailable)
  end

  private

  def launch_oidc_rp_logout!(client_id:)
    completion_region = rp_logout_region
    session_record = oidc_rp_logout_session
    resource_type = oidc_rp_logout_resource_type
    # The verified local binding identifies the only Refresh Token the RP may revoke. Visa's
    # independent OP-wide confirmation is always a no-hint browser step.
    refresh_token = current_oidc_rp_refresh_token(session_record)

    post_logout_redirect_uri = registered_rp_logout_redirect_uri(
      client_id:, resource_type:, region: completion_region,
    )
    state = SecureRandom.urlsafe_base64(32)
    prepare_oidc_rp_sign_out_notice!(state:, session_record:)
    unless cancel_visa_o9_admissions_before_rp_revoke!(session_record)
      return render_oidc_rp_logout_unavailable(status: :service_unavailable)
    end

    begin
      revoke_oidc_rp_session_before_redirect!(session_record)
    rescue ActiveRecord::ActiveRecordError, PG::Error => e
      Rails.logger.error(
        "auth.sign_out.rp_local_revoke_failed error_class=#{e.class.name} result=unavailable",
      )
      return render_oidc_rp_logout_unavailable(status: :service_unavailable)
    end

    handoff_oidc_rp_logout_to_op!(
      client_id:, resource_type:, refresh_token:, post_logout_redirect_uri:, state:,
    )
  rescue OidcClientRegistry::ClientNotFound, OidcRpLogoutError, URI::InvalidURIError,
         RpSession::IssuanceRejected, ActiveRecord::ActiveRecordError => e
    Rails.logger.warn(
      "auth.sign_out.rp_initiated_logout_rejected " \
      "error_class=#{e.class.name} result=unavailable",
    )
    render_oidc_rp_logout_unavailable
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

    # Every surface's completion renderer reads this flag, either explicitly or through
    # inertia_rails' default, so a completion reached in a later request still clears history.
    session[:inertia_clear_history] = true
    render_oidc_rp_logout_completion
  end

  def handoff_oidc_rp_logout_to_op!(client_id:, resource_type:, refresh_token:,
                                    post_logout_redirect_uri:, state:)
    clear_oidc_rp_logout_cookies!
    reset_session_and_clear_inertia_history!
    Actor.clear
    @current_resource = nil
    @oidc_rp_logout_session = nil
    @oidc_rp_logout_access_payload = nil
    revoke_oidc_rp_refresh_token(client_id:, resource_type:, token: refresh_token) if refresh_token
    issue_sign_out_notice!
    redirect_to(
      oidc_rp_end_session_url(
        resource_type:, client_id:, post_logout_redirect_uri:, state:,
      ),
      allow_other_host: true,
      status: :see_other,
    )
  end

  class OidcRpLogoutError < StandardError; end

  private

  def resolve_oidc_rp_logout_credentials
    access_plain = cookies[OidcRpBrowserCredentialContract::ACCESS_COOKIE].to_s.presence
    return if access_plain.blank?

    access_state = resolve_rp_cell_access(access_plain)
    return unless access_state.status == :valid
    return unless access_state.rp_session&.active?

    [access_state.rp_session, access_state.resource, access_state.payload]
  rescue ArgumentError
    nil
  end

  def oidc_rp_logout_resource_type
    OidcIssuer.resource_type_for_client(OidcClientRegistry.find!(oidc_client_id))
  end

  def current_oidc_rp_refresh_token(session_record)
    raw_token = cookies[OidcRpBrowserCredentialContract::REFRESH_COOKIE].to_s.presence
    return unless raw_token

    token_parts = raw_token.split(RefreshTokenShared::REFRESH_TOKEN_SEPARATOR, 2)
    return unless token_parts.length == 2 && token_parts.all?(&:present?)

    public_id = token_parts.first
    binding_sid = session_record.op_session_binding&.sid
    access_sid = AuthorizationTokenClaims.session_id(@oidc_rp_logout_access_payload)
    return unless secure_public_id_match?(binding_sid, access_sid)
    return unless secure_public_id_match?(binding_sid, public_id)

    raw_token
  end

  def secure_public_id_match?(expected, actual)
    expected_value = expected.to_s
    actual_value = actual.to_s
    expected_value.present? && actual_value.present? && expected_value.bytesize == actual_value.bytesize &&
      ActiveSupport::SecurityUtils.secure_compare(expected_value, actual_value)
  end

  def revoke_oidc_rp_refresh_token(client_id:, resource_type:, token:)
    result = OidcOpRevocationClient.revoke(client_id:, resource_type:, token:)
    return if result.success?

    Rails.logger.warn(
      "auth.sign_out.rp_refresh_revocation_unavailable " \
      "client_id=#{client_id} outcome=#{result.outcome}",
    )
  end

  def oidc_rp_logout_session
    @oidc_rp_logout_session || raise(OidcRpLogoutError, "RP Session was not authenticated")
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
    clear_rp_cell_session_cookie!
    @current_access_token_payload = nil
  end

  def prepare_oidc_rp_sign_out_notice!(state:, session_record:)
    @sign_out_actor_ref = oidc_rp_logout_resource.try(:public_id)
    @sign_out_session_public_id = session_record.public_id
    @sign_out_state = state
  end

  def revoke_oidc_rp_session_before_redirect!(session_record)
    session_record.class.connection_class_for_self.connected_to(role: :writing) do
      session_record.with_lock do
        if session_record.revoked_at.blank?
          session_record.update!(revoked_at: session_record.class.database_now)
        end
      end
    end
  end

  def cancel_visa_o9_admissions_before_rp_revoke!(session_record)
    surface =
      case session_record
      when RpBaseAppSession then "app"
      when RpBaseOrgSession then "org"
      else return true
      end
    access_token = BrowserCredentialCookie.read(cookies, OidcRpBrowserCredentialContract::ACCESS_COOKIE)
    result = VisaSensitiveAdmissionClient.new(surface:, access_token:)
      .revoke_rp_session(rp_session_ref: session_record.public_id)
    return true if result.ok?

    Rails.logger.error(
      "auth.sign_out.o9_session_cancellation_failed surface=#{surface} result=#{result.status}",
    )
    false
  end

  def registered_rp_logout_redirect_uri(client_id:, resource_type:, region:)
    client = OidcClientRegistry.find!(client_id)
    candidate =
      client.post_logout_redirect_uris.find do |uri|
        parsed = URI.parse(uri)
        parsed.host == request.host &&
          parsed.path == AuthBoundaryAuthorityMap::CANONICAL_RP_SIGN_OUT_PATH &&
          Rack::Utils.parse_nested_query(parsed.query.to_s) == { "ri" => region.to_s }
      end
    unless candidate && OidcClientRegistry.valid_post_logout_redirect_uri?(
      client_id:, uri: candidate, resource_type:,
    )
      raise OidcRpLogoutError, "registered post_logout_redirect_uri is unavailable"
    end

    candidate
  end

  def oidc_rp_end_session_url(resource_type:, client_id:, post_logout_redirect_uri:, state:)
    uri = URI.parse(OidcIssuer.end_session_endpoint(resource_type))
    query = Rack::Utils.parse_nested_query(uri.query.to_s)
    query.merge!(
      "client_id" => client_id,
      "post_logout_redirect_uri" => post_logout_redirect_uri,
      "state" => state,
    )
    uri.query = query.to_query
    uri.to_s
  end

  def render_oidc_rp_logout_unavailable(status: :unprocessable_content)
    response.headers["Cache-Control"] = "private, no-store"
    response.headers["Referrer-Policy"] = "strict-origin"
    render "auth/shared/sign_outs/unavailable", status: status
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

  def logout_surface_name
    controller_path.split("/").second
  end
end
