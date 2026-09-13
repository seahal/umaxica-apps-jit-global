# typed: false
# frozen_string_literal: true

module AuthenticationJwtTokens
  extend ActiveSupport::Concern

  def encode_login_access_token(resource, token_record, token_kind_id:, dpop_jkt:, access_expires_at:)
    AuthenticationToken.encode(
      resource,
      host: request.host,
      session_public_id: token_session_public_id(token_record),
      oidc_sid: token_session_public_id(token_record),
      oidc_jti: token_record_oidc_jti(token_record),
      resource_type: resource_type,
      dpop_jkt: dpop_jkt,
      expires_at: SessionAbsoluteExpiryValue.cap(
        proposed_expiry: access_expires_at,
        absolute_expiry: token_record_expiry_at(token_record),
      ),
      acr: "aal1",
      amr: normalize_amr(token_kind_id, token_record: token_record),
      jwt_issuer_id: auth_jwt_issuer_id,
      authentication_context: token_record_authentication_context(token_record),
    )
  end

  private

  def encode_refreshed_access_token(resource, token_record, access_expires_at)
    AuthenticationToken.encode(
      resource,
      host: request.host,
      session_public_id: token_session_public_id(token_record),
      oidc_sid: token_session_public_id(token_record),
      oidc_jti: token_record_oidc_jti(token_record),
      resource_type: resource_type,
      dpop_jkt: token_record_attribute(token_record, :dpop_jkt),
      expires_at: SessionAbsoluteExpiryValue.cap(
        proposed_expiry: access_expires_at,
        absolute_expiry: token_record_expiry_at(token_record),
      ),
      acr: "aal1",
      amr: nil,
      jwt_issuer_id: auth_jwt_issuer_id,
      authentication_context: token_record_authentication_context(token_record),
    )
  end

  def current_session_public_id_from_access_token
    access_token = extract_access_token(AuthenticationBase::ACCESS_COOKIE_KEY)
    return nil if access_token.blank?
    return nil if request&.host.blank?

    AuthenticationToken.extract_session_id_allow_expired(
      access_token,
      host: request.host,
      resource_type: resource_type,
      jwt_issuer_id: auth_jwt_issuer_id,
    )
  end

  # The session row is the single authority for the authentication context, and
  # every access token -- first issue, refresh rotation, and mid-session
  # reissue -- reads it from here. A continuation therefore cannot mint a Normal
  # token for an Emergency session: there is nowhere else for the value to come
  # from. See docs/security/org-emergency-access.md.
  def token_record_authentication_context(token_record)
    return nil unless token_record.respond_to?(:authentication_context_value)

    token_record.authentication_context_value.to_s
  end

  def token_record_oidc_sid(token_record)
    token_session_public_id(token_record).presence ||
      token_record_attribute(token_record, :oidc_sid).presence ||
      token_record&.public_id
  end

  def token_record_oidc_jti(token_record)
    token_record_attribute(token_record, :oidc_jti).presence
  end

  def token_session_public_id(token_record)
    token_record&.try(:device_session)&.public_id.presence ||
      token_record&.public_id
  end

  def token_record_attribute(token_record, attribute)
    return unless token_record&.has_attribute?(attribute)

    token_record.public_send(attribute)
  end

  def token_record_column?(column_name)
    token_class.respond_to?(:column_names) && token_class.column_names.include?(column_name)
  end

  def uuid_identifier?(value)
    /\A[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}\z/i.match?(
      value.to_s,
    )
  end

  def reissue_access_token!
    resource = current_resource
    return unless resource
    return unless current_session

    now = Time.current
    access_expires_at = access_token_expires_at_for(current_session, now: now)

    new_access_token = AuthenticationToken.encode(
      resource,
      host: request.host,
      session_public_id: token_session_public_id(current_session),
      oidc_sid: token_session_public_id(current_session),
      oidc_jti: token_record_oidc_jti(current_session),
      resource_type: resource_type,
      dpop_jkt: token_record_attribute(current_session, :dpop_jkt),
      expires_at: access_expires_at,
      jwt_issuer_id: auth_jwt_issuer_id,
      authentication_context: token_record_authentication_context(current_session),
    )
    return unless new_access_token

    cookies[AuthenticationBase::ACCESS_COOKIE_KEY] = cookie_options.merge(
      value: new_access_token,
      expires: access_expires_at,
    )
    Actor.install_context!(preferences: resolved_current_preference(resource)) if respond_to?(
      :resolved_current_preference, true,
    )
  end

  def access_token_expires_at_for(token_record, now: Time.current)
    SessionAbsoluteExpiryValue.cap(
      proposed_expiry: now + AuthenticationBase::ACCESS_TOKEN_TTL,
      absolute_expiry: token_record_expiry_at(token_record),
    )
  end

  def auth_jwt_issuer_id
    "surface:#{auth_jwt_namespace}"
  end

  def auth_jwt_namespace
    return "SIGN_#{resource_surface_key.to_s.upcase}" unless respond_to?(:controller_path)

    service, surface = controller_path.to_s.split("/", 3)
    service = service.to_s.upcase
    surface = surface.to_s.upcase
    namespace = "#{service}_#{surface}"
    return namespace if JitSecurityJwtRegistry::SURFACE_NAMESPACES.include?(namespace)

    "SIGN_#{resource_surface_key.to_s.upcase}"
  end

  def resource_surface_key
    case resource_type
    when "operator" then "org"
    when "visitor" then "com"
    else "app"
    end
  end
end
