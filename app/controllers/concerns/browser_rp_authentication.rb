# typed: false
# frozen_string_literal: true

# Shared Browser RP authentication. It authenticates only the RP access cookie
# and follows its sid to one verified RP Session, the owning Browser Session,
# and that session's current root token. The root chain is live security
# context, never a fallback credential when the RP cookie is absent.
module BrowserRpAuthentication
  extend ActiveSupport::Concern

  AccessState = Data.define(:status, :resource, :rp_session, :payload, :security_context)
  AccessPolicyContext = Data.define(
    :policy,
    :options,
    :controller_name,
    :action_name,
    :logged_in,
    :current_resource_deactivated,
  )

  VALID_POLICIES = %i(deny_all public_strict auth_required guest_only).freeze
  POLICY_AUTHENTICATION_MODES = {
    deny_all: :deny_all,
    public_strict: :open,
    auth_required: :private,
    guest_only: :guest,
  }.freeze
  AUTHENTICATION_MODE_POLICIES = {
    bare: :public_strict,
    deny_all: :deny_all,
    guest: :guest_only,
    private: :auth_required,
    open: :public_strict,
  }.freeze
  AUTHENTICATION_MODE_RULES = Concurrent::Map.new
  ACCESS_POLICY_RULES = Concurrent::Map.new
  AUTHENTICATION_REQUIRED_REASONS = {
    missing: "access_credential_missing",
    invalid: "access_credential_invalid",
  }.freeze
  private_constant :AUTHENTICATION_REQUIRED_REASONS

  class InvalidPolicyError < StandardError; end

  class MissingPolicyError < StandardError; end

  class SkipNotAllowedError < StandardError; end

  included do
    include ::AuthenticationWithdrawalGate

    after_action :verify_private_action_authorized! if respond_to?(:after_action)
    after_action :apply_authenticated_page_cache_policy! if respond_to?(:after_action)
    helper_method :current_resource, :browser_rp_authenticated?, :browser_rp_session_public_id,
                  :current_browser_session_security_context, :current_session_public_id,
                  :current_session, :logged_in?
  end

  class_methods do
    def access_policy_rules
      ACCESS_POLICY_RULES.fetch_or_store(self) { [] }
    end

    def access_policy(policy, only: nil, except: nil, **options)
      policy = policy.to_sym
      raise InvalidPolicyError, "Invalid policy: #{policy.inspect}" unless VALID_POLICIES.include?(policy)

      rule = {
        policy: policy,
        only: Array(only).map(&:to_s).presence,
        except: Array(except).map(&:to_s).presence,
        options: options,
      }
      ACCESS_POLICY_RULES[self] = access_policy_rules + [rule]
      declare_authentication_mode!(POLICY_AUTHENTICATION_MODES.fetch(policy), only: only, except: except, **options)
    end

    def authentication_mode_rules
      AUTHENTICATION_MODE_RULES.fetch_or_store(self) { [] }
    end

    def local_authentication_mode_rules
      authentication_mode_rules
    end

    def declare_authentication_mode!(mode, only: nil, except: nil, **options)
      mode = mode.to_sym
      unless %i(bare deny_all guest private open).include?(mode)
        raise InvalidPolicyError, "Invalid authentication mode: #{mode.inspect}"
      end

      rule = {
        mode: mode,
        only: Array(only).map(&:to_s).presence,
        except: Array(except).map(&:to_s).presence,
        options: options,
      }
      AUTHENTICATION_MODE_RULES[self] = authentication_mode_rules + [rule]
    end

    def authentication_mode_for(action)
      action = action.to_s
      authentication_mode_rules.reverse_each do |rule|
        next if rule[:only].present? && rule[:only].exclude?(action)
        next if rule[:except].present? && rule[:except].include?(action)

        return rule[:mode]
      end

      return const_get(:AUTHENTICATION_MODE, false) if const_defined?(:AUTHENTICATION_MODE, false)

      :deny_all
    end

    def skip_before_action(*filters, **options)
      flattened = filters.flatten
      action_names =
        flattened.filter_map do |filter|
          next unless filter.respond_to?(:to_sym) && !filter.is_a?(Hash)

          filter.to_sym
        end
      if action_names.include?(:enforce_access_policy!)
        raise SkipNotAllowedError, "skip_before_action :enforce_access_policy! is prohibited (#{name})"
      end

      super
    end
  end

  public

  def current_resource
    browser_rp_access_state.resource
  end

  def current_account
    current_resource
  end

  def current_client
    current_resource if browser_rp_resource_type.to_s == "client"
  end

  def current_visitor
    current_resource if browser_rp_resource_type.to_s == "visitor"
  end

  def current_operator
    current_resource if browser_rp_resource_type.to_s == "operator"
  end

  def active_client?
    current_client&.active? || false
  end

  def active_visitor?
    current_visitor&.active? || false
  end

  def active_operator?
    current_operator&.active? || false
  end

  def logged_in_client?
    current_client.present?
  end

  def logged_in_visitor?
    current_visitor.present?
  end

  def logged_in_operator?
    current_operator.present?
  end

  def am_i_client?
    browser_rp_resource_type.to_s == "client"
  end

  def am_i_user?
    am_i_client?
  end

  def am_i_operator?
    browser_rp_resource_type.to_s == "operator"
  end

  def am_i_staff?
    am_i_operator?
  end

  def logged_in?
    browser_rp_authenticated?
  end

  def authentication_credentials_invalid?
    browser_rp_access_state.status == :invalid
  end

  def verify_private_action_authorized!
    return unless self.class.authentication_mode_for(action_name) == :private

    verify_authorized
  end

  def apply_authenticated_page_cache_policy!
    return unless authenticated_page_response?
    return if response.headers["Cache-Control"].to_s.split(",").map(&:strip).include?("no-store")

    response.set_header("Cache-Control", "no-store")
  end

  def authenticated_page_response?
    return false unless response.media_type == "text/html" || response.headers["X-Inertia"] == "true"

    mode = self.class.authentication_mode_for(action_name)
    return true if mode == :private
    return false if mode == :bare

    logged_in?
  end

  def enforce_access_policy!
    mode = self.class.authentication_mode_for(action_name)
    case mode
    when :deny_all
      raise MissingPolicyError,
            "Denied by default authentication mode for #{self.class.name}##{action_name}. " \
            "Declare a concrete authentication mode before exposing this endpoint."
    when :bare, :open
      return true unless authentication_credentials_invalid?

      clear_browser_rp_cookies!
      return true if browser_rp_invalid_credentials_are_ignored?

      render_browser_rp_invalid_credentials!
      false
    when :private
      authenticate_browser_rp!
    when :guest
      return true unless browser_rp_authenticated?

      render plain: I18n.t("errors.messages.operation_not_permitted"), status: :forbidden,
             content_type: "text/plain"
      false
    else
      raise InvalidPolicyError, "Unexpected authentication mode: #{mode.inspect}"
    end
  end

  def access_policy_context(policy, options)
    AccessPolicyContext.new(
      policy: policy,
      options: options,
      controller_name: self.class.name,
      action_name: action_name,
      logged_in: browser_rp_authenticated?,
      current_resource_deactivated: current_resource_deactivated_for_policy?,
    )
  end

  def access_policy_allows?(rule, context)
    allowed_to?(rule, context, with: Authentication::AccessPolicy)
  end

  def policy_for_authentication_mode(mode)
    AUTHENTICATION_MODE_POLICIES.fetch(mode.to_sym)
  rescue KeyError
    raise InvalidPolicyError, "Unexpected authentication mode: #{mode.inspect}"
  end

  def access_policy_options_for(action)
    resolve_browser_rp_authentication_mode_rule_for(action)&.fetch(:options, {}) ||
      resolve_browser_rp_access_policy_for(action)&.fetch(:options, {}) ||
      {}
  end

  def browser_rp_authenticated?
    browser_rp_access_state.status == :valid
  end

  def authenticate_browser_rp!
    return true if browser_rp_authenticated?
    return false if browser_rp_dependency_failed?

    log_browser_rp_authentication_required!
    clear_browser_rp_cookies! if browser_rp_access_state.status == :invalid
    render_browser_rp_unauthenticated!
    false
  end

  def current_session_public_id
    current_browser_session_security_context&.root_session_public_id
  end

  def current_session
    current_browser_session_security_context&.root_token
  end

  def browser_rp_session_public_id
    current_browser_session_security_context&.rp_session_public_id
  end

  def current_browser_session_security_context
    browser_rp_access_state.security_context
  end

  def current_session_restricted?
    current_browser_session_security_context&.restricted? || false
  end

  protected

  # Presence flags only: they separate an access credential the browser stopped sending from a
  # refused one, without recording either credential.
  def log_browser_rp_authentication_required!
    Rails.logger.info(
      JitLogEvent.format(
        "auth.session.authentication_required",
        occurred_at: Time.current.utc.iso8601(3),
        request_id: request.request_id,
        controller: self.class.name,
        action: action_name,
        failure_reason: AUTHENTICATION_REQUIRED_REASONS.fetch(browser_rp_access_state.status),
        access_credential_presented: request.cookies.key?(OidcRpBrowserCredentialContract::ACCESS_COOKIE),
        refresh_credential_presented: request.cookies.key?(OidcRpBrowserCredentialContract::REFRESH_COOKIE),
        # Strict credentials are withheld on a cross-site navigation; this tells that case apart.
        fetch_site: request.headers["Sec-Fetch-Site"].presence_in(%w(same-origin same-site cross-site none)),
      ),
    )
  end

  def browser_rp_client_id
    raise NotImplementedError, "controller must define browser_rp_client_id"
  end

  def browser_rp_resource_type
    raise NotImplementedError, "controller must define browser_rp_resource_type"
  end

  def browser_rp_resource_class
    case browser_rp_resource_type.to_s
    when "operator" then Operator
    when "visitor" then Visitor
    when "client" then Client
    else raise ArgumentError, "unsupported Browser RP resource type"
    end
  end

  def browser_rp_root_token_class
    case browser_rp_resource_type.to_s
    when "operator" then OperatorToken
    when "visitor" then VisitorToken
    when "client" then ClientToken
    else raise ArgumentError, "unsupported Browser RP resource type"
    end
  end

  def browser_rp_resource_foreign_key
    case browser_rp_resource_type.to_s
    when "operator" then :staff_id
    when "visitor" then :visitor_id
    when "client" then :user_id
    else raise ArgumentError, "unsupported Browser RP resource type"
    end
  end

  def browser_rp_session_class
    case browser_rp_resource_type.to_s
    when "operator" then OperatorRpSession
    when "visitor" then VisitorRpSession
    when "client" then ClientRpSession
    else raise ArgumentError, "unsupported Browser RP resource type"
    end
  end

  def browser_rp_connection_owner
    case browser_rp_resource_type.to_s
    when "operator" then OrgTicketRecord
    when "visitor" then ComTicketRecord
    when "client" then AppTicketRecord
    else raise ArgumentError, "unsupported Browser RP resource type"
    end
  end

  def resource_class
    browser_rp_resource_class
  end

  def token_class
    browser_rp_root_token_class
  end

  def resource_type
    browser_rp_resource_type
  end

  def resource_foreign_key
    browser_rp_resource_foreign_key
  end

  def browser_rp_trusted_origins
    []
  end

  def browser_rp_invalid_credentials_are_ignored?
    false
  end

  def browser_rp_unauthenticated_redirect_path
    return unless request.format.html?

    case controller_path.split("/").first
    when "base", "core", "edit", "warp"
      sign_in_url_with_pt(encoded_pt(request.fullpath))
    end
  end

  def current_resource_deactivated_for_policy?
    resource = current_resource
    resource.respond_to?(:deactivated?) && resource.deactivated?
  end

  def render_browser_rp_unauthenticated!
    response.set_header("Cache-Control", "no-store")
    redirect_path = browser_rp_unauthenticated_redirect_path
    if redirect_path.present?
      redirect_to(redirect_path, allow_other_host: false)
      return
    end

    render plain: "Authentication required", status: :unauthorized, content_type: "text/plain"
  end

  def render_browser_rp_invalid_credentials!
    response.set_header("Cache-Control", "no-store")
    render plain: "Authentication required", status: :unauthorized, content_type: "text/plain"
  end

  def render_browser_rp_dependency_failure!
    response.set_header("Cache-Control", "no-store")
    render plain: "Service unavailable", status: :service_unavailable, content_type: "text/plain"
  end

  def browser_rp_access_state
    return @browser_rp_access_state if defined?(@browser_rp_access_state)

    @browser_rp_access_state = resolve_browser_rp_access_cookie
  rescue ActiveRecord::ActiveRecordError
    @browser_rp_dependency_failed = true
    render_browser_rp_dependency_failure! unless performed?
    @browser_rp_access_state = AccessState.new(
      status: :missing,
      resource: nil,
      rp_session: nil,
      payload: nil,
      security_context: nil,
    )
  end

  def resolve_browser_rp_authentication_mode_rule_for(action)
    action = action.to_s
    self.class.local_authentication_mode_rules.reverse_each do |rule|
      next if rule[:only].present? && rule[:only].exclude?(action)
      next if rule[:except].present? && rule[:except].include?(action)

      return rule
    end
    nil
  end

  def resolve_browser_rp_access_policy_for(action)
    action = action.to_s
    self.class.access_policy_rules.reverse_each do |rule|
      next if rule[:only].present? && rule[:only].exclude?(action)
      next if rule[:except].present? && rule[:except].include?(action)

      return rule
    end
    nil
  end

  def browser_rp_dependency_failed?
    defined?(@browser_rp_dependency_failed) && @browser_rp_dependency_failed
  end

  def resolve_browser_rp_access_cookie(access_token: nil)
    access_token ||= BrowserCredentialCookie.read(cookies, OidcRpBrowserCredentialContract::ACCESS_COOKIE)
    return AccessState.new(status: :missing, resource: nil, rp_session: nil, payload: nil, security_context: nil) if
      access_token.blank?

    payload = OidcRpBrowserCredentialContract.decode_access_token(
      token: access_token,
      host: request.host,
      resource_type: browser_rp_resource_type,
      client_id: browser_rp_client_id,
    )
    unless payload
      return AccessState.new(status: :invalid, resource: nil, rp_session: nil, payload: nil, security_context: nil)
    end

    session_public_id = AuthorizationTokenClaims.session_id(payload).to_s
    rp_session = find_browser_rp_session(session_public_id)
    resource = browser_rp_resource_for(rp_session)
    root_token = rp_session&.parent_token
    browser_session = rp_session&.parent_device_session
    return invalid_browser_rp_access unless valid_browser_rp_chain?(
      payload, rp_session, resource, browser_session, root_token,
    )

    security_context = BrowserSessionSecurityContext.new(
      resource: resource,
      browser_session: browser_session,
      root_token: root_token,
      rp_session: rp_session,
      access_payload: payload,
    )
    @current_access_token_payload = payload
    AccessState.new(
      status: :valid,
      resource: resource,
      rp_session: rp_session,
      payload: payload,
      security_context: security_context,
    )
  rescue ActiveRecord::RecordNotFound
    invalid_browser_rp_access
  end

  def find_browser_rp_session(public_id)
    return if public_id.blank?

    browser_rp_connection_owner.connected_to(role: :writing) do
      browser_rp_session_class.uncached do
        browser_rp_session_class.find_by(public_id: public_id, oidc_client_id: browser_rp_client_id)
      end
    end
  end

  def browser_rp_resource_for(rp_session)
    return unless rp_session

    case rp_session
    when OperatorRpSession then rp_session.staff
    when VisitorRpSession then rp_session.visitor
    when ClientRpSession then rp_session.user
    else raise ArgumentError, "unsupported Browser RP Session class"
    end
  end

  def valid_browser_rp_chain?(payload, rp_session, resource, browser_session, root_token)
    return false unless rp_session && resource && browser_session && root_token
    return false unless rp_session.oidc_client_id == browser_rp_client_id
    return false unless browser_session.current_refresh_token_id == root_token.id
    return false unless browser_session.usable? && root_token.currently_usable?
    return false unless rp_session.active?
    return false unless resource.is_a?(browser_rp_resource_class) && resource.active?
    return false unless AuthorizationTokenClaims.base_session_id(payload).to_s == root_token.public_id.to_s

    expected_subject = OidcSubject.for(resource, resource_type: browser_rp_resource_type)
    actual_subject = AuthorizationTokenClaims.subject(payload).to_s
    return false unless expected_subject.bytesize == actual_subject.bytesize

    ActiveSupport::SecurityUtils.secure_compare(expected_subject, actual_subject)
  end

  def invalid_browser_rp_access
    AccessState.new(status: :invalid, resource: nil, rp_session: nil, payload: nil, security_context: nil)
  end

  def clear_browser_rp_access_cookie!
    cookies.delete(
      OidcRpBrowserCredentialContract::ACCESS_COOKIE,
      OidcRpBrowserCredentialContract.access_cookie_deletion_options,
    )
    @current_access_token_payload = nil
  end

  def clear_browser_rp_cookies!
    clear_browser_rp_access_cookie!
    cookies.delete(
      OidcRpBrowserCredentialContract::REFRESH_COOKIE,
      OidcRpBrowserCredentialContract.refresh_cookie_deletion_options,
    )
    @browser_rp_access_state = AccessState.new(
      status: :missing,
      resource: nil,
      rp_session: nil,
      payload: nil,
      security_context: nil,
    )
  end

  def install_browser_rp_token_response!(result)
    token_response = result.token_response
    access_token, refresh_token = OidcRpBrowserCredentialContract.require_token_response!(token_response)
    now = browser_rp_database_now
    access_expires_at = result.access_expires_at ||
      OidcRpBrowserCredentialContract.access_expires_at_from_response(token_response, now: now)
    refresh_expires_at = result.refresh_expires_at ||
      OidcRpBrowserCredentialContract.refresh_expires_at_from_response(token_response, now: now)
    raise ArgumentError, "RP refresh expiry precedes access expiry" if refresh_expires_at < access_expires_at

    cookies[OidcRpBrowserCredentialContract::ACCESS_COOKIE] =
      OidcRpBrowserCredentialContract.access_cookie_options(expires_at: access_expires_at).merge(
        value: access_token,
      )
    cookies[OidcRpBrowserCredentialContract::REFRESH_COOKIE] =
      OidcRpBrowserCredentialContract.refresh_cookie_options(expires_at: refresh_expires_at).merge(
        value: refresh_token,
      )
    @browser_rp_access_state = resolve_browser_rp_access_cookie(access_token: access_token)
    browser_rp_access_state
  end

  def browser_rp_database_now
    browser_rp_session_class.database_now
  end

  def refresh_browser_rp_credentials!
    refresh_token = BrowserCredentialCookie.read(cookies, OidcRpBrowserCredentialContract::REFRESH_COOKIE)
    return :missing if invalid_browser_rp_refresh_value?(refresh_token)

    token_endpoint_uri = OidcIssuer.token_endpoint(browser_rp_resource_type)
    client_assertion = OidcClientAssertionJwt.issue(
      client_id: browser_rp_client_id,
      token_url: token_endpoint_uri,
    )
    result = OidcTokenExchangeCoordinator.call(
      grant_type: "refresh_token",
      refresh_token: refresh_token,
      client_id: browser_rp_client_id,
      client_assertion_type: OidcClientAssertionJwt::ASSERTION_TYPE,
      client_assertion: client_assertion,
      token_endpoint_uri: token_endpoint_uri,
      request_method: "POST",
      expected_resource_type: browser_rp_resource_type,
    )
    handle_browser_rp_refresh_result(result)
  rescue ActiveRecord::ActiveRecordError, Umaxica::Valkey::Unavailable,
         Umaxica::Valkey::SerializationError, Umaxica::Valkey::OperationError
    @browser_rp_dependency_failed = true
    render_browser_rp_dependency_failure!
    :dependency
  end

  def handle_browser_rp_refresh_result(result)
    if result.success?
      install_browser_rp_token_response!(result)
      return :success
    end

    if result.error.to_s.in?(%w(server_error temporarily_unavailable))
      @browser_rp_dependency_failed = true
      render_browser_rp_dependency_failure!
      return :dependency
    end

    clear_browser_rp_cookies!
    :invalid
  end

  def invalid_browser_rp_refresh_value?(value)
    value.blank? || value.include?("\0") || value != value.strip
  end
end
