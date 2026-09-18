# typed: false
# frozen_string_literal: true

module AuthenticationRedirects
  extend ActiveSupport::Concern
  include CommonRedirect
  include ::RedirectsSignedTargetSupport

  DEFAULT_PT_SESSION_KEY = AuthIoKeys::Session::DEFAULT_PT
  PATH_TARGET_TOKEN_SALT = "path_target_token"
  PATH_TARGET_TOKEN_PURPOSE = :path_target
  PATH_TARGET_TOKEN_EXPIRES_IN = 15.minutes

  # Preserves the redirect parameter in session and returns it for immediate use
  #
  # @param session_key [Symbol] The session key to store pt parameter in
  # @return [String, nil] The pt parameter value if present
  def preserve_pt(session_key = DEFAULT_PT_SESSION_KEY)
    value = signed_pt_param
    return if value.blank?

    session[session_key] = value
    value
  end

  # Retrieves and clears the redirect parameter from session
  # Falls back to the signed params[:pt] if session is empty
  #
  # @param session_key [Symbol] The session key to retrieve from
  # @return [String, nil] The pt parameter value
  def retrieve_pt(session_key = DEFAULT_PT_SESSION_KEY)
    pt_param = signed_pt_param.presence || session[session_key]
    session.delete(session_key)
    pt_param
  end

  # Retrieves redirect parameter without clearing session
  #
  # @param session_key [Symbol] The session key to retrieve from
  # @return [String, nil] The pt parameter value
  def peek_pt(session_key = DEFAULT_PT_SESSION_KEY)
    signed_pt_param.presence || session[session_key]
  end

  # Builds redirect params hash with optional pt parameter.
  # Automatically includes pt from params or session if present.
  #
  # @param message_key [Symbol] Either :notice or :alert
  # @param message_value [String] The message text or translation key result
  # @param session_key [Symbol] The session key to check for pt parameter
  # @return [Hash] Redirect params hash
  def build_redirect_params(message_key, message_value, session_key = DEFAULT_PT_SESSION_KEY)
    redirect_params = { message_key => message_value }
    pt_value = peek_pt(session_key)
    redirect_params[AuthIoKeys::Params::PT] = pt_value if pt_value.present?
    redirect_params
  end

  # Builds redirect params hash with notice message
  #
  # @param message_value [String] The notice message
  # @param session_key [Symbol] The session key to check for pt parameter
  # @return [Hash] Redirect params with notice
  def build_notice_params(message_value, session_key = DEFAULT_PT_SESSION_KEY)
    build_redirect_params(:notice, message_value, session_key)
  end

  # Builds redirect params hash with alert message
  #
  # @param message_value [String] The alert message
  # @param session_key [Symbol] The session key to check for pt parameter
  # @return [Hash] Redirect params with alert
  def build_alert_params(message_value, session_key = DEFAULT_PT_SESSION_KEY)
    build_redirect_params(:alert, message_value, session_key)
  end

  # Performs redirect with pt parameter handling.
  # Either redirects to encoded pt URL or falls back to default path.
  #
  # @param default_path [String] Default path if no pt parameter
  # @param _message_key [Symbol] Legacy message kind, retained for caller compatibility
  # @param _message_value [String] Legacy message value, intentionally not persisted across redirects
  # @param session_key [Symbol] The session key for pt parameter
  def redirect_with_pt_handling(default_path, _message_key, _message_value,
                                session_key = DEFAULT_PT_SESSION_KEY)
    pt_param = retrieve_pt(session_key)

    if pt_param.present?
      destination = path_from_signed_pt(pt_param) || default_path
      redirect_to_pt_destination!(destination)
    else
      redirect_to(default_path)
    end
  end

  # Performs redirect with notice message and pt handling
  #
  # @param default_path [String] Default path if no pt parameter
  # @param message_value [String] Notice message value
  # @param session_key [Symbol] The session key for pt parameter
  def redirect_with_notice(default_path, message_value, session_key = DEFAULT_PT_SESSION_KEY)
    redirect_with_pt_handling(default_path, :notice, message_value, session_key)
  end

  # Performs redirect with alert message and pt handling
  #
  # @param default_path [String] Default path if no pt parameter
  # @param message_value [String] Alert message value
  # @param session_key [Symbol] The session key for pt parameter
  def redirect_with_alert(default_path, message_value, session_key = DEFAULT_PT_SESSION_KEY)
    redirect_with_pt_handling(default_path, :alert, message_value, session_key)
  end

  # Adds pt parameter to existing redirect params if present
  # Modifies the hash in place
  #
  # @param redirect_params [Hash] The redirect params hash to modify
  # @param session_key [Symbol] The session key to check for pt parameter
  # @return [Hash] The modified redirect_params hash
  def add_pt_to_params!(redirect_params, session_key = DEFAULT_PT_SESSION_KEY)
    pt_value = peek_pt(session_key)
    redirect_params[AuthIoKeys::Params::PT] = pt_value if pt_value.present?
    redirect_params
  end

  def redirect_to_pt_or_default!(pt_param, default_path:)
    destination = path_from_signed_pt(pt_param)
    return redirect_to(default_path) if pt_param.blank?
    return render_invalid_return_target! if destination.blank?

    redirect_to_pt_destination!(destination)
  end

  def sign_in_checkpoint_path(pt: nil)
    attrs = { ri: current_region_identifier }
    safe_pt = signed_pt_token(pt)
    attrs[AuthIoKeys::Params::PT] = safe_pt if safe_pt.present?

    if respond_to?(:auth_app_sign_in_check_path, true)
      auth_app_sign_in_check_path(**attrs)
    elsif respond_to?(:auth_org_sign_in_check_path, true)
      auth_org_sign_in_check_path(**attrs)
    elsif respond_to?(:auth_com_sign_in_check_path, true)
      auth_com_sign_in_check_path(**attrs)
    else
      "/sign/in/check"
    end
  end

  def sign_in_welcome_path(pt: nil, id: nil)
    attrs = { ri: current_region_identifier }
    safe_pt = signed_pt_token(pt)
    attrs[AuthIoKeys::Params::PT] = safe_pt if safe_pt.present?
    _ = id

    case sign_in_surface
    when :app
      base_app_welcome_url(
        **attrs,
        host: ENV.fetch("PRIVATE_BASE_SERVICE_URL"),
      )
    when :com
      base_com_welcome_url(
        **attrs,
        host: ENV.fetch("PRIVATE_BASE_CORPORATE_URL"),
      )
    when :org
      base_org_welcome_url(
        **attrs,
        host: ENV.fetch("PRIVATE_BASE_STAFF_URL"),
      )
    else
      path = "/welcome"
      query = attrs.compact.to_query
      query.present? ? "#{path}?#{query}" : path
    end
  end

  def sign_in_dashboard_path(pt: nil)
    _ = pt

    case sign_in_surface
    when :app
      base_app_root_url(
        ri: params[:ri],
        host: ENV.fetch("PUBLIC_BASE_SERVICE_URL"),
      )
    when :com
      base_com_root_url(
        ri: params[:ri],
        host: ENV.fetch("PRIVATE_BASE_CORPORATE_URL"),
      )
    when :org
      base_org_root_url(
        ri: params[:ri],
        host: ENV.fetch("PRIVATE_BASE_STAFF_URL"),
      )
    else
      "/"
    end
  end

  def after_welcome_path
    sign_in_dashboard_path
  end

  alias after_dashboard_path after_welcome_path

  def sign_in_surface
    case self.class.name
    when /\A(Auth|Sign|Acme)::App::/ then :app
    when /\A(Auth|Sign|Acme)::Com::/ then :com
    when /\A(Auth|Sign|Acme)::Org::/ then :org
    end
  end

  def path_from_signed_pt(pt_param)
    return nil if pt_param.blank?

    destination = verify_authentication_pt_path(pt_param)
    safe_non_welcome_return_path(destination)
  end

  def signed_pt_token(pt_param)
    return if pt_param.blank?

    token = pt_param.to_s
    verified_destination = verify_authentication_pt_path(token)
    if safe_non_welcome_return_path(verified_destination).present?
      return token
    end

    issued_token = issue_authentication_path_target_token(token)
    issued_token if path_from_signed_pt(issued_token).present?
  end

  def path_target_value
    params[AuthIoKeys::Params::PT].presence
  end

  def signed_pt_param
    token = path_target_value.to_s.presence
    return if token.blank?

    return token if path_from_signed_pt(token).present?

    log_signed_target_rejection(
      "path_target.rejected",
      signed_pt_rejection_reason(token),
    )
    nil
  end

  def signed_pt_rejection_reason(token)
    return "missing" if token.blank?
    return "malformed" unless token.is_a?(String)

    payload = signed_pt_verification_payload(token)
    return "expired" if payload == :expired
    return "signature_invalid" if payload.nil?

    "verifier_error"
  end

  def signed_pt_verification_payload(token)
    verified_signed_target_payload(
      token,
      purpose: PATH_TARGET_TOKEN_PURPOSE,
      salt: PATH_TARGET_TOKEN_SALT,
      expected_flow: authentication_pt_flow,
      expected_surface: authentication_pt_surface,
      session_nonce: authentication_pt_session_nonce,
    )
  rescue ActiveSupport::MessageVerifier::InvalidSignature
    :expired
  rescue StandardError
    nil
  end

  def resolved_path_or_navigation_target(scope: :authentication)
    navigation_target = params[AuthIoKeys::Params::NT].presence
    if navigation_target.present?
      result = ::RedirectsNavigationTargetResolver.call(
        navigation_target,
        routes: self,
        params: redirect_target_context_params,
        scope: scope,
      )
      return result.value if result.ok?

      log_redirect_target_failure(result)
      return nil
    end

    path_from_signed_pt(path_target_value)
  end

  def safe_non_welcome_return_path(path)
    safe_path = safe_internal_path(path)
    return nil if safe_path.blank?
    return nil if welcome_return_path?(safe_path)

    safe_path
  end

  alias safe_non_dashboard_return_path safe_non_welcome_return_path

  def welcome_return_path?(path)
    candidate = URI.parse(path.to_s)
    welcome = URI.parse(sign_in_welcome_path)
    candidate.path == welcome.path || candidate.path == "/welcome" || candidate.path.start_with?("/welcomes/")
  rescue URI::InvalidURIError
    false
  end

  alias dashboard_return_path? welcome_return_path?

  def issue_authentication_path_target_token(return_to)
    destination = signed_target_internal_path(return_to)
    if destination.blank?
      log_signed_target_rejection("path_target.rejected", "blank_pt")
      return nil
    end

    claims = signed_target_claims(
      flow: authentication_pt_flow,
      surface: authentication_pt_surface,
      session_nonce: authentication_pt_session_nonce,
    )
    if claims.blank?
      log_signed_target_rejection("path_target.rejected", "blank_common_claim")
      return nil
    end

    issue_signed_target_token(
      payload: claims.merge("pt" => destination),
      purpose: PATH_TARGET_TOKEN_PURPOSE,
      salt: PATH_TARGET_TOKEN_SALT,
      expires_in: PATH_TARGET_TOKEN_EXPIRES_IN,
    )
  end

  def verify_authentication_pt_path(token)
    payload = verified_signed_target_payload(
      token,
      purpose: PATH_TARGET_TOKEN_PURPOSE,
      salt: PATH_TARGET_TOKEN_SALT,
      expected_flow: authentication_pt_flow,
      expected_surface: authentication_pt_surface,
      session_nonce: authentication_pt_session_nonce,
    )
    return nil if payload.blank?

    signed_target_internal_path(payload["pt"])
  end

  def redirect_to_pt_destination!(destination)
    path = safe_internal_path(destination)
    path ||= default_after_login_path

    redirect_to(path, allow_other_host: false)
  end

  def authentication_pt_flow
    "authentication"
  end

  def authentication_pt_surface
    surface_from_controller_name || Actor.tld.presence || "app"
  end

  def surface_from_controller_name
    case self.class.name
    when /::App::/ then "app"
    when /::Com::/ then "com"
    when /::Org::/ then "org"
    end
  end

  def authentication_pt_session_nonce
    session[:authentication_pt_nonce] ||=
      session[:authentication_return_target_nonce] || SecureRandom.urlsafe_base64(24)
    session[:authentication_return_target_nonce] ||= session[:authentication_pt_nonce]
  end

  def authentication_return_target_nonce
    authentication_pt_session_nonce
  end

  def render_invalid_return_target!
    render(
      plain: I18n.t("errors.messages.invalid_request"),
      status: :unprocessable_content,
    )
  end
end
