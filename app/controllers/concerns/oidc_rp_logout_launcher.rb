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
      render plain: "Authentication required", status: :unauthorized
      return
    end

    @oidc_rp_logout_session, @oidc_rp_logout_resource, @oidc_rp_logout_access_payload = resolved
    @current_resource = @oidc_rp_logout_resource
    @current_session_public_id = @oidc_rp_logout_session.public_id
  end

  private

  def launch_oidc_rp_logout!(client_id:, issuer_resource_type: nil, token_issuer: nil, session_authority: :rp_session)
    _ = [issuer_resource_type, token_issuer, session_authority]
    completion_region = rp_logout_region
    session_record = oidc_rp_logout_session
    resource_type = oidc_rp_logout_resource_type
    # WU-14: a grant whose callback stored no verified ID Token has no hint and cannot start logout.
    hint = session_record&.association(:logout_hint)&.scope&.take
    return render_oidc_rp_logout_unavailable unless hint

    id_token = hint.id_token

    post_logout_redirect_uri = registered_rp_logout_redirect_uri(
      client_id:, resource_type:, region: completion_region,
    )
    state = SecureRandom.urlsafe_base64(32)
    prepare_oidc_rp_sign_out_notice!(state:, session_record:)
    revoke_oidc_rp_session_before_redirect!(session_record)
    clear_oidc_rp_logout_cookies!
    reset_session_and_clear_inertia_history!
    issue_sign_out_notice!
    Actor.clear if defined?(Actor)
    @current_resource = nil
    @oidc_rp_logout_session = nil
    @oidc_rp_logout_access_payload = nil
    redirect_to(
      oidc_rp_end_session_url(
        resource_type:,
        id_token:,
        client_id:,
        post_logout_redirect_uri:,
        state:,
      ),
      allow_other_host: true,
      status: :see_other,
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

  class OidcRpLogoutError < StandardError; end

  private

  def resolve_oidc_rp_logout_credentials
    return resolve_rp_cell_logout_credentials if rp_cell_process?

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

  def resolve_rp_cell_logout_credentials
    access_plain = cookies[OidcRpBrowserCredentialContract::ACCESS_COOKIE].to_s.presence
    return if access_plain.blank?

    access_state = resolve_rp_cell_access(access_plain)
    return unless access_state.status == :valid
    return unless access_state.rp_session&.active?

    [access_state.rp_session, access_state.resource, access_state.payload]
  rescue ActiveRecord::ActiveRecordError, ArgumentError
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
    when "operator" then OpOrgGrant
    when "visitor" then OpComGrant
    when "client" then OpAppGrant
    else raise ArgumentError, "unsupported RP Session resource type"
    end
  end

  def oidc_rp_logout_session_relation_for(resource_type)
    case resource_type.to_s
    when "operator" then OpOrgGrant.includes(operator_device_session: :staff)
    when "visitor" then OpComGrant.includes(visitor_device_session: :visitor)
    when "client" then OpAppGrant.includes(client_device_session: :user)
    else raise ArgumentError, "unsupported RP Session resource type"
    end
  end

  def oidc_rp_logout_connection_for(resource_type)
    case resource_type.to_s
    when "operator" then OpBaseOrgRecord
    when "visitor" then OpBaseComRecord
    else OpBaseAppRecord
    end
  end

  def find_oidc_rp_logout_session(public_id:, client_id:, resource_type:)
    return if public_id.blank?

    oidc_rp_logout_connection_for(resource_type).connected_to(role: :writing) do
      oidc_rp_logout_session_relation_for(resource_type).find_by(
        public_id: public_id,
        oidc_client_id: client_id,
      )
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
    return session_record.active? if rp_cell_process?
    return false if session_record.revoked?

    session_record.parent_token_active?
  end

  def oidc_rp_logout_resource_for(session_record)
    return @oidc_rp_logout_resource if rp_cell_process?

    case session_record
    when OpOrgGrant then session_record.staff
    when OpComGrant then session_record.visitor
    else session_record.user
    end
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
    clear_rp_cell_session_cookie! if rp_cell_process?
    @current_access_token_payload = nil
  end

  def prepare_oidc_rp_sign_out_notice!(state:, session_record:)
    @sign_out_actor_ref = oidc_rp_logout_resource.try(:public_id)
    @sign_out_session_public_id = session_record.public_id
    @sign_out_state = state
  end

  def revoke_oidc_rp_session_before_redirect!(session_record)
    if rp_cell_process?
      session_record.class.connection_class.connected_to(role: :writing) do
        session_record.with_lock do
          if session_record.revoked_at.blank?
            session_record.update!(revoked_at: session_record.class.database_now)
          end
        end
      end
      return
    end

    result = RpSessionRevoker.call(
      scope: :rp_session, record: session_record, cause: "token_revocation",
      authority_evidence_ref: "rp_initiated_logout:grant",
    )
    raise RpSession::IssuanceRejected, "RP Session revoke failed" unless result.success?
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

  def oidc_rp_end_session_url(resource_type:, id_token:, client_id:, post_logout_redirect_uri:, state:)
    uri = URI.parse(OidcIssuer.end_session_endpoint(resource_type))
    query = Rack::Utils.parse_nested_query(uri.query.to_s)
    query.merge!(
      "id_token_hint" => id_token,
      "client_id" => client_id,
      "post_logout_redirect_uri" => post_logout_redirect_uri,
      "state" => state,
    )
    uri.query = query.to_query
    uri.to_s
  end

  def render_oidc_rp_logout_unavailable
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

  def logout_surface_name
    controller_path.split("/").second
  end
end
