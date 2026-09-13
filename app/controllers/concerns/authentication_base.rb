# typed: false
# frozen_string_literal: true

require "jwt"
require_relative "../../models/concerns/refresh_token_shared"

module AuthenticationBase
  extend ActiveSupport::Concern
  include DbscCanonicalUrl
  include AuthenticationRedirects
  include AuthenticationCookieStore
  include AuthenticationJwtTokens
  include AuthenticationBulletinGate
  include AuthenticationSequenceGate
  include AuthenticationDeviceBinding
  include ::RefreshTokenShared
  include AuthenticationLogoutable
  include AuthenticationWithdrawalGate

  # ==========================================================================
  # TOC (approximate)
  # 1) JWT & AuthenticationToken primitives ....................................... L40-L210
  # 2) Request guards (public API, I/O boundary) .................... L215-L275
  # 3) Redirect/checkpoint session flows (I/O boundary) ............. L277-L462
  # 4) Session auth lifecycle (public API, I/O boundary) ............ L464-L775
  # 5) Abstract contract & policy DSL ............................... L778-L907
  # 6) Private request/cookie/token I/O ............................. L909-L1505
  # 7) Policy/domain decisions ...................................... L1514-L1869
  # 8) MFA/session helper decisions ................................. L1873-L1966
  # ==========================================================================

  included do
    after_action :verify_private_action_authorized! if respond_to?(:after_action)
  end

  # ==========================================================================
  # 1) JWT & AuthenticationToken primitives
  # ==========================================================================

  # --- Policy errors ---
  class MissingPolicyError < StandardError; end

  class InvalidPolicyError < StandardError; end

  class SkipNotAllowedError < StandardError; end

  VALID_POLICIES = %i(
    deny_all
    public_strict
    auth_required
    guest_only
  ).freeze

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

  ACCESS_POLICY_RULES = Concurrent::Map.new
  AUTHENTICATION_MODE_RULES = Concurrent::Map.new

  AccessPolicyContext = Struct.new(
    :policy,
    :options,
    :controller_name,
    :action_name,
    :logged_in,
    :current_resource_deactivated,
    keyword_init: true,
  )

  # Cookie keys - environment-dependent naming
  # Production: "__Host-" prefix for host-only secure cookies
  # Dev/Test: no prefix (String, not Symbol)
  ACCESS_COOKIE_KEY = AuthenticationCookieName.access
  REFRESH_COOKIE_KEY = AuthenticationCookieName.refresh
  DBSC_COOKIE_KEY = AuthenticationCookieName.dbsc
  BULLETIN_SESSION_KEY = :sign_in_checkpoint
  BULLETIN_TIMEOUT = 2.hours
  OIDC_RP_SESSION_KEYS = %i(
    oidc_code_verifier
    oidc_state
    oidc_nonce
    oidc_pt
    oidc_authorization_login_challenge
  ).freeze

  # AuthenticationToken TTLs
  ACCESS_TOKEN_TTL = ::SecurityTokenLifetimes::AUTH_ACCESS_JWT_TTL
  REFRESH_TOKEN_TTL = ::SecurityTokenLifetimes::CLIENT_REFRESH_TOKEN_TTL
  DBSC_COOKIE_TTL = 10.minutes
  RESTRICTED_SESSION_TTL = 15.minutes
  SESSION_LIMIT_HARD_REJECT_MESSAGE = I18n.t("errors.messages.session_limit_exceeded")
  LOGIN_COOLDOWN_MESSAGE = I18n.t("errors.messages.login_cooldown")

  class LoginCooldownError < StandardError; end

  class ConcurrentSessionLimitExceededError < StandardError; end

  class << self
    # Prevents rapid re-login by enforcing a cooldown between sessions. The window is
    # application configuration (config/initializers/login_cooldown.rb), read on every
    # check so that no mutable state is held here; a zero duration disables the gate.
    def login_cooldown
      Rails.application.config.x.authentication.login_cooldown
    end
  end

  def params(*filters)
    return ActionController::Parameters.new if request.blank?

    raw_params = super()
    return raw_params if filters.empty?

    raw_params.expect(*filters)
  end

  AUDIT_EVENTS = {
    logged_in: "LOGGED_IN",
    logged_out: "LOGGED_OUT",
    logout_current_session: "LOGGED_OUT",
    logout_all_sessions: "LOGOUT",
    login_failed: "LOGIN_FAILED",
    token_refreshed: "TOKEN_REFRESHED",
  }.freeze

  VALID_ACTOR_TYPES = %w(client operator visitor).freeze

  # JWT primitives and gateway-level concerns were extracted out of
  # this 3,000-line module into dedicated files. The constant aliases
  # below preserve every existing reference such as
  # `AuthenticationToken.decode(...)` and
  # `AuthenticationJwtConfiguration.issuer`. New code
  # should reference `AuthenticationToken` and
  # `AuthenticationJwtConfiguration` directly. See CQ-1.
  AuthenticationJwtConfiguration = AuthenticationJwtConfiguration
  AuthenticationToken = AuthenticationToken

  def logged_in?
    current_resource.present?
  end

  # ======================================================================
  # 2) Request guards (public API, Request I/O boundary)
  # - Reads request format and writes HTTP response
  # ======================================================================

  # Ensures user is not already logged in
  # Renders bad_request with message if user is logged in
  # Used for authentication endpoints (login)
  #
  # @param message_key [String] Optional translation key for the error message
  # @return [nil] Returns nil if user is logged in (stops filter chain)
  def ensure_not_logged_in(message_key: nil)
    return unless logged_in?

    message = message_key ? t(message_key) : I18n.t("errors.messages.not_authorized")
    render plain: message, status: :unauthorized
    nil
  end

  # Ensures user is not already logged in (registration variant)
  # AuthenticationRedirects to root with alert message if user is logged in
  # Used for registration endpoints
  #
  # @param redirect_path [String] Path to redirect to (default: "/")
  # @param message_key [String] Optional translation key for the alert message
  def ensure_not_logged_in_for_registration(redirect_path: "/", message_key: nil)
    return unless logged_in?

    message = message_key ? t(message_key) : I18n.t("errors.messages.not_authorized")

    if request.format.json?
      render plain: message, status: :unauthorized
    else
      redirect_to(redirect_path, alert: message)
    end
  end

  # Checks if user is logged in and renders error if so (inline variant)
  # Returns true if user is logged in, false otherwise
  # Useful for inline checks in actions
  #
  # @param message_key [String] Translation key for the error message
  # @return [Boolean] true if user is logged in, false otherwise
  def reject_if_logged_in(message_key)
    if logged_in?
      render plain: t(message_key), status: :bad_request
      true
    else
      false
    end
  end

  # Reject if user/staff is already logged in with 401 Unauthorized
  def reject_logged_in_session
    return unless logged_in?

    render plain: I18n.t("errors.messages.already_authenticated"), status: :unauthorized
  end

  def render_sign_in_unavailable_while_authenticated(_exception = nil)
    response.set_header("Cache-Control", "no-store")
    render plain: AlreadyAuthenticatedError::MESSAGE, status: :conflict
  end

  # ======================================================================
  # 3) Redirect/checkpoint session flows (Session/params I/O boundary)
  # - Reads/writes params, flash, session
  # ======================================================================

  # Default session key for storing return-to parameter.
  DEFAULT_PT_SESSION_KEY = AuthIoKeys::Session::DEFAULT_PT
  CHECKPOINT_SESSION_KEY = AuthIoKeys::Session::CHECKPOINT
  # ======================================================================
  # 4) Session auth lifecycle (public API, Cookie/session/request I/O boundary)
  # ======================================================================

  # Loads authentication session data and validates expiry
  # Returns the found record or handles redirect on expiry
  #
  # @param session_key [Symbol, String] The session key to load from
  # @param model_class [Class] The model class to load
  # @param redirect_path [String, Symbol] Where to redirect on session expiry
  # @param redirect_message [String] The translation key for expiry message
  # @param block [Proc] Optional block for additional validation
  # @return [ActiveRecord::Base, nil] The loaded record or nil
  def load_authentication_session(session_key, model_class, redirect_path, redirect_message)
    record = nil

    if session[session_key].present?
      record = model_class.find_by(id: session[session_key])

      # If block provided, use it for validation; otherwise just check presence
      is_valid =
        if block_given?
          yield(record)
        else
          record.present?
        end

      return record if is_valid

      # Session expired or invalid
      handle_session_expiry(redirect_path, redirect_message)
      nil
    else
      # No session data
      handle_session_expiry(redirect_path, redirect_message)
      nil
    end
  end

  # Stores authentication session data
  #
  # @param session_key [Symbol, String] The session key to store to
  # @param value [Object] The value to store (typically an ID or hash)
  def store_authentication_session(session_key, value)
    session[session_key] = value
  end

  # Clears authentication session data
  #
  # @param session_keys [Array<Symbol, String>] The session keys to clear
  def clear_authentication_session(*session_keys)
    session_keys.each do |key|
      session.delete(key)
    end
  end

  # Validates session expiry against a timestamp
  #
  # @param session_data [Hash] The session data containing expiry information
  # @param expiry_key [String, Symbol] The key in session_data that contains expiry timestamp
  # @return [Boolean] true if not expired, false otherwise
  def validate_session_expiry(session_data, expiry_key = "expires_at")
    return false if session_data.blank?
    return true unless session_data[expiry_key]

    epoch_seconds(session_data[expiry_key]) > Time.current.to_i
  end

  # Loads a record from session with additional validation
  #
  # @param session_key [Symbol, String] The session key containing the record ID
  # @param model_class [Class] The model class to load
  # @param validations [Hash] Additional validations to perform
  # @return [ActiveRecord::Base, nil] The loaded record or nil

  def load_session_record(session_key, model_class, validations = {})
    return nil if session[session_key].blank?

    operation =
      -> {
        scope = model_class
        scope = scope.includes(*Array(validations[:includes])) if validations[:includes]
        scope.find_by(id: session[session_key])
      }
    record = defined?(Prosopite) ? Prosopite.pause(&operation) : operation.call
    return nil if record.blank?

    # Check OTP expiry if requested
    if validations[:check_otp_expiry] && record.respond_to?(:otp_expired?)
      return nil if record.otp_expired?
    end

    # Check status_id if provided
    if validations[:status_id] && record.respond_to?(:user_email_status_id)
      return nil if record.user_email_status_id != validations[:status_id]
    end

    # Run custom validation if provided
    if validations[:custom]
      return nil unless validations[:custom].call(record)
    end

    record
  end

  def current_account
    current_resource
  end

  def current_session_public_id
    actor_session_public_id = Actor.authn.login_public_id if defined?(Actor)
    return actor_session_public_id if actor_session_public_id.present?

    @current_session_public_id ||= current_session_public_id_from_access_token
  end

  def current_resource
    actor_resource = actor_current_resource
    return actor_resource if actor_resource.present?
    return @current_resource if defined?(@current_resource)

    @current_resource = load_current_resource
  end

  def log_in(resource, record_login_audit: true, token_kind_id: "BROWSER_WEB", require_totp_check: true,
             audit_context: {}, bootstrap_actor: false, skip_login_cooldown: false,
             established_authentication_method: nil, authentication_context: nil)
    return { status: :access_locked } if administratively_locked_resource?(resource)
    return { status: :login_forbidden } unless resource.login_allowed?

    check_login_cooldown!(
      resource,
      bootstrap_actor: bootstrap_actor,
      skip_login_cooldown: skip_login_cooldown,
    )

    totp_result = check_totp_requirement_before_session_rotation(require_totp_check, resource)
    return totp_result if totp_result

    oidc_rp_session_state = preserved_oidc_rp_session_state

    reset_session
    restore_oidc_rp_session_state!(oidc_rp_session_state)
    clear_previous_login_cookies!

    with_actor_session_lock(resource) do
      issue_login_tokens_within_lock(
        resource, record_login_audit: record_login_audit, token_kind_id: token_kind_id,
                  audit_context: audit_context, bootstrap_actor: bootstrap_actor,
                  established_authentication_method: established_authentication_method,
                  authentication_context: authentication_context,
      )
    end
  rescue ConcurrentSessionLimitExceededError
    session_limit_hard_reject_result(resource)
  end

  # Vocabulary for `established_authentication_method` (adr/unified-enforcement.md,
  # Session attribution). Deliberately distinct from `auth_method:` (a flow-type
  # marker also used for MFA gating and audit context -- values like
  # "session_limit_promotion" or "social" are never authentication methods) and
  # from the OIDC `amr` claim. Only genuine primary-credential auth_method values
  # map to a symbol here; anything else resolves to nil, which is a defined, safe
  # state (adr/unified-enforcement.md, Session revocation) rather than a guess.
  ESTABLISHED_AUTHENTICATION_METHOD_MAP = {
    "email" => "email",
    "telephone" => "telephone",
    "secret_credential" => "secret",
    "passkey" => "passkey",
    "totp" => "totp",
    "google" => "google",
    "apple" => "apple",
    "entra_id" => "entra",
    "entra" => "entra",
  }.freeze

  def established_authentication_method_for(auth_method)
    ESTABLISHED_AUTHENTICATION_METHOD_MAP[auth_method.to_s]
  end

  def check_totp_requirement_before_session_rotation(require_totp_check, resource)
    return unless require_totp_check

    check_totp_requirement(resource)
  end

  # Serialize the count-then-create critical section in `log_in` for a
  # single actor. Uses a row-level lock on the resource record so that two
  # concurrent log_in attempts for the same actor cannot both observe the
  # same session-count snapshot. The lock lives in the resource's DB; the
  # block may itself open transactions against the token DB.
  def with_actor_session_lock(resource)
    return yield unless resource&.class&.respond_to?(:transaction)

    result = nil
    owner = resource_connection_owner(resource.class)
    owner.connected_to(role: :writing) do
      resource.class.transaction do
        resource.lock!
        result = yield
      end
    end
    result
  end

  def resource_connection_owner(klass)
    connection_owner = klass
    connection_owner = connection_owner.superclass until connection_owner.connection_class? ||
        connection_owner == ApplicationRecord
    connection_owner
  end

  def clear_previous_login_cookies!
    cookies.delete(ACCESS_COOKIE_KEY, cookie_deletion_options)
    cookies.delete(REFRESH_COOKIE_KEY, cookie_deletion_options)
    clear_dbsc_cookie!
  end

  def preserved_oidc_rp_session_state
    OIDC_RP_SESSION_KEYS.index_with do |key|
      session[key]
    end.compact
  end

  def restore_oidc_rp_session_state!(state)
    state.each do |key, value|
      session[key] = value
    end
  end

  def session_limit_hard_reject_result(resource)
    Rails.logger.info(
      JitLogEvent.format(
        "session.limit.hard_reject",
        "#{resource_type}_id": resource.id,
        ip_address: request_ip_address,
      ),
    )
    {
      status: :session_limit_hard_reject,
      http_status: :forbidden,
      message: SESSION_LIMIT_HARD_REJECT_MESSAGE,
    }
  end

  def validate_login_dpop_proof
    dpop_proof = request.headers["DPoP"]
    return { status: :success, jkt: nil } if dpop_proof.blank?

    proof_result = DpopProofVerifier.new(
      proof_jwt: dpop_proof,
      request_method: request.request_method,
      request_uri: request.original_url,
      resource_type: resource_type,
    ).call
    return { status: :dpop_proof_invalid, error: proof_result.error } unless proof_result.valid?

    { status: :success, jkt: proof_result.jkt }
  end

  def rotate_login_refresh_token!(token_record, restricted_expires_at)
    token_record_connection_owner(token_record.class).connected_to(role: :writing) do
      token_record.rotate_refresh_token!(discarded_at: restricted_expires_at)
    end
  end

  def issue_login_tokens_within_lock(resource, record_login_audit:, token_kind_id:, audit_context:, bootstrap_actor:,
                                     established_authentication_method: nil, authentication_context: nil)
    # Sign-up handoff must always issue an active token. If a rare data
    # condition (e.g. an orphan social_identity that resolves to a
    # session-saturated actor) made `session_limit_state_for` return
    # :issue_restricted or :hard_reject for a freshly minted actor,
    # the user would land on /sign/in/session immediately after
    # finishing registration -- a UX break with no upside. Skip the
    # gate entirely when the caller asserts this is a bootstrap login.
    session_limit_state = bootstrap_actor ? :within_limit : session_limit_state_for(resource)
    return session_limit_hard_reject_result(resource) if session_limit_state == :hard_reject

    is_restricted = session_limit_state == :issue_restricted
    store_pending_login_resource(resource) if is_restricted

    dpop_result = validate_login_dpop_proof
    return { status: dpop_result[:status], error: dpop_result[:error] } unless dpop_result[:status] == :success

    now = Time.current
    resolved_token_kind_id = resolve_token_kind_id(token_kind_id)
    token_status_id = is_restricted ? token_class::STATUS_RESTRICTED : token_class::STATUS_ACTIVE
    token_record = create_login_token_record(
      resource,
      resolved_token_kind_id,
      token_status_id: token_status_id,
      dpop_jkt: dpop_result[:jkt],
      established_authentication_method: established_authentication_method,
      authentication_context: authentication_context,
    )
    device_session = ensure_device_session_for!(resource, token_record, dpop_jkt: dpop_result[:jkt])
    restricted_expires_at = is_restricted ? restricted_session_expires_at : nil
    refresh_plain = rotate_login_refresh_token!(token_record, restricted_expires_at)
    update_device_session_refresh_state!(device_session, token_record)
    notify_restricted_session_issued(resource, token_record, restricted_expires_at) if is_restricted

    adopt_preference_for!(resource) if respond_to?(:adopt_preference_for!, true)

    access_expires_at = access_token_expires_at_for(token_record, now: now)
    access_token = encode_login_access_token(
      resource,
      token_record,
      token_kind_id: token_kind_id,
      dpop_jkt: dpop_result[:jkt],
      access_expires_at: access_expires_at,
    )

    @current_resource = resource
    @current_session = token_record
    @current_session_public_id = token_session_public_id(token_record)

    set_login_auth_cookies(token_record, access_token, refresh_plain, access_expires_at)
    issue_dbsc_registration_header_for(token_record)
    populate_current_attributes!(resource, nil)
    @_current_resource_resolved = true
    emit_session_issued(resource, token_record, token_kind_id, restricted: is_restricted)
    record_audit(AUDIT_EVENTS[:logged_in], resource: resource, context: audit_context) if record_login_audit

    login_result(token_record, access_token, refresh_plain, access_expires_at, now, restricted: is_restricted)
  end

  def notify_restricted_session_issued(resource, token_record, restricted_expires_at)
    Rails.logger.info(
      JitLogEvent.format(
        "session.restricted.issued",
        "#{resource_type}_id": resource.id,
        user_token_id: token_record.public_id,
        expires_at: restricted_expires_at&.iso8601,
        ip_address: request_ip_address,
      ),
    )
  end

  def emit_session_issued(resource, token_record, token_kind_id, restricted:)
    SignRiskEmitter.emit(
      "session_issued",
      **risk_actor_payload(resource.id),
      user_token_id: token_record.public_id,
      ip: request&.remote_ip,
      user_agent: request&.user_agent,
      request_id: request&.request_id,
      meta: { auth_method: token_kind_id, restricted: restricted },
    )
  end

  def login_result(token_record, access_token, refresh_plain, access_expires_at, now, restricted:)
    result = login_success_payload(token_record, access_token, refresh_plain, access_expires_at, now)
    return result unless restricted

    issue_session_limit_gate!(
      pt: session_limit_gate_pt,
      flow: session_limit_gate_flow,
    )
    result.merge(restricted: true, session_management_required: true)
  end

  def login_success_payload(token_record, access_token, refresh_plain, access_expires_at, now)
    {
      status: :success,
      access_token: access_token,
      refresh_token: refresh_plain,
      token_type: access_token_response_type(token_record),
      expires_in: expires_in_for(access_expires_at, now: now),
      dbsc: dbsc_payload_for(token_record),
    }
  end

  def refresh_access_token(refresh_plain, allow_suspended: false)
    clear_refresh_failure!

    refresh_public_id, = token_class.parse_refresh_token(refresh_plain.to_s)
    token_record = find_refresh_token_record(refresh_public_id)
    return handle_restricted_refresh_rejected(token_record, refresh_public_id) if token_record&.restricted?

    return handle_refresh_idle_timeout(token_record, refresh_public_id) unless refresh_idle_allowed?(token_record)

    return handle_refresh_binding_denied(
      token_record,
      refresh_public_id,
    ) unless refresh_dpop_allowed?(token_record) && refresh_binding_allowed?(token_record)

    result = AcmeRefreshTokenIssuer.call(refresh_token: refresh_plain)
    return handle_invalid_refresh_token_result(result, refresh_public_id, token_record) unless result.success?

    previous_token_record = result[:previous_token] || token_record
    token_record = result[:token]
    new_refresh_plain = result[:refresh_token]

    return handle_missing_refresh_token(refresh_public_id) unless token_record.is_a?(token_class)
    return handle_refresh_binding_denied(
      token_record,
      refresh_public_id,
    ) unless device_session_refresh_allowed?(token_record)

    # Load resource from token record
    # Use the same code path for all environments.
    resource = token_record.public_send(token_resource_prefix)

    if administratively_locked_resource?(resource)
      return handle_administrative_access_locked_refresh(resource, refresh_public_id, token_record)
    end

    unless refreshable_resource?(resource, allow_suspended: allow_suspended)
      return handle_inactive_resource(resource, refresh_public_id, token_record)
    end

    build_refreshed_session(
      resource, token_record, new_refresh_plain,
      previous_token_record: previous_token_record,
    )
  rescue StandardError => e
    Rails.logger.error(
      JitLogEvent.format(
        "auth.token.refresh.error",
        error_class: e.class.name,
        message: e.message,
        exception: e,
      ),
    )
    handle_refresh_error(e, refresh_public_id, resource)
  end

  def refresh_failure_status
    @refresh_failure_status || :unauthorized
  end

  def refresh_failure_code
    @refresh_failure_code || "invalid_refresh_token"
  end

  def log_out
    logout_current_session!(reason: "user_logout")
  end

  def transparent_refresh_access_token
    return unless transparent_refresh_allowed?
    return if extract_access_token(ACCESS_COOKIE_KEY).present?
    return if request.env[AuthIoKeys::Env::AUTH_REFRESHED_FLAG]

    refresh_plain = cookies[REFRESH_COOKIE_KEY]
    return if refresh_plain.blank?

    refresh_result = attempt_transparent_refresh!(refresh_plain)
    unless refresh_result
      Rails.logger.debug(JitLogEvent.format("auth.transparent_refresh.failed"))
      clear_auth_cookies!
      return
    end

    Rails.logger.debug(
      JitLogEvent.format(
        "auth.transparent_refresh.success",
        user_present: refresh_result[:user].present?,
      ),
    )
    @current_resource = refresh_result[:user]
  end

  def authenticate!
    if logged_in?
      SignRiskEnforcer.call(current_resource)
      return
    end

    if request.format.json?
      render json: { error: "Unauthorized" }, status: :unauthorized
    else
      SignRiskEmitter.emit(
        "auth_required",
        ip: request&.remote_ip,
        user_agent: request&.user_agent,
        request_id: request&.request_id,
        path: request&.fullpath,
        method: request&.request_method,
      )
      store_authentication_return_target!(request.fullpath) unless respond_to?(
        :redirect_to_oidc_authorization_url,
        true,
      )
      pt =
        if respond_to?(:encoded_pt, true)
          encoded_pt(request.fullpath)
        end
      url = sign_in_url_with_pt(pt)
      redirect_options = {
        fallback_internal: true,
        alert: I18n.t("errors.messages.login_required"),
      }
      if respond_to?(:redirect_to_oidc_authorization_url, true)
        redirect_to_oidc_authorization_url(url, **redirect_options)
      else
        redirect_to_jump_url(url, **redirect_options)
      end

      convert_redirect_to_inertia_location!
    end
  end

  # An Inertia visit is a `fetch` call, so a 3xx is followed by the browser transparently and the
  # client ends up parsing the credential ceremony's HTML as though it were an Inertia response. It
  # raises "All Inertia requests must receive a valid Inertia response" and the application stays on
  # the page it was already showing, with no way to reach sign-in.
  #
  # The Inertia protocol reserves 409 + X-Inertia-Location for leaving the Inertia application; the
  # client turns it into a full document visit. Authentication redirects always leave the
  # application -- they go to the OIDC authorization endpoint or the jump gateway, neither of which
  # renders an Inertia response -- so the conversion applies to every branch above.
  def convert_redirect_to_inertia_location!
    return unless request.respond_to?(:inertia?) && request.inertia?
    return unless response.redirect?

    location = response.location

    # This is `InertiaRails::Controller#inertia_location` written out. That helper calls `head`,
    # which refuses to run once a response body exists, and the redirect above has already written
    # one. Assigning the status, the header and the body directly replaces the redirect in place
    # without tripping AbstractController::DoubleRenderError.
    response.headers.delete("Location")
    response.headers["X-Inertia-Location"] = location
    self.status = :conflict
    self.response_body = ""
  end

  # Abstract methods - must be implemented by including modules
  def resource_class
    raise NotImplementedError, "resource_class must be implemented"
  end

  def token_class
    raise NotImplementedError, "token_class must be implemented"
  end

  def audit_class
    raise NotImplementedError, "audit_class must be implemented"
  end

  def resource_type
    raise NotImplementedError, "resource_type must be implemented"
  end

  def resource_foreign_key
    raise NotImplementedError, "resource_foreign_key must be implemented"
  end

  def sign_in_url_with_pt(return_to)
    raise NotImplementedError, "sign_in_url_with_pt must be implemented"
  end

  def store_authentication_return_target!(return_to)
    token = issue_authentication_path_target_token(return_to)
    session[DEFAULT_PT_SESSION_KEY] = token if token.present?
    token
  end

  # Authorization abstract methods - RBAC / ABAC placeholders
  def am_i_user?
    raise NotImplementedError, "am_i_user? must be implemented"
  end

  def am_i_operator?
    raise NotImplementedError, "am_i_operator? must be implemented"
  end

  def am_i_owner?
    raise NotImplementedError, "am_i_owner? must be implemented"
  end

  # ==========================================================================
  # 5) Abstract contract & policy DSL (controller class API)
  # ==========================================================================
  class_methods do
    # Declare policy for controller or specific actions (only/except).
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
      declare_authentication_mode_for_policy!(policy, only: only, except: except)
    end

    def authentication_mode_rules
      AUTHENTICATION_MODE_RULES.fetch_or_store(self) { [] }
    end

    def local_authentication_mode_rules
      authentication_mode_rules
    end

    def declare_authentication_mode!(mode, only: nil, except: nil, **options)
      mode = mode.to_sym
      raise InvalidPolicyError,
            "Invalid authentication mode: #{mode.inspect}" unless authentication_modes.include?(mode)

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

    def authentication_modes
      %i(bare deny_all guest private open)
    end

    private

    def declare_authentication_mode_for_policy!(policy, only:, except:)
      rule = access_policy_rules.last

      declare_authentication_mode!(
        POLICY_AUTHENTICATION_MODES.fetch(policy),
        only: only,
        except: except,
        **(rule&.fetch(:options, {}) || {}),
      )
    end

    public

    # --- Skip guardrails ---
    # Disallow removing enforce_access_policy! via skip_before_action.
    def skip_before_action(*filters, **options)
      # Note: In Ruby 4.0+/Rails 8+, some callers pass Hash as positional argument
      # instead of keyword arguments. Filter out non-symbol entries.
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

    # Some code uses skip_action_callback, so lock this down too.
    def skip_action_callback(*args, **kwargs)
      # skip_action_callback(:process_action, :before, :enforce_access_policy!)
      if args.map(&:to_sym).include?(:enforce_access_policy!)
        raise SkipNotAllowedError, "skip_action_callback :enforce_access_policy! is prohibited (#{name})"
      end

      super
    end
  end

  private

  # ----------------------------------------------------------------------
  # 3-2) Bulletin private helpers
  # ----------------------------------------------------------------------

  # ======================================================================
  # 6) Private request/cookie/token I/O helpers
  # ======================================================================
  # Withdrawal gate has moved to AuthenticationWithdrawalGate (see CQ-1).
  # The methods `enforce_withdrawal_gate!`, `withdrawal_gate_allowlisted?`,
  # `withdrawal_restricted_resource?`, and `withdrawal_gate_redirect_path`
  # are still available on every controller that includes
  # AuthenticationBase via the `include AuthenticationWithdrawalGate` at the top.

  # ----------------------------------------------------------------------
  # 6-3) Audit/occurrence writing (side-effect boundary)
  # ----------------------------------------------------------------------
  def record_audit(event_id, resource:, actor: resource, context: {})
    return unless resource && event_id

    Rails.logger.debug(
      JitLogEvent.format(
        "auth.audit.recording",
        event_id: event_id,
        resource_id: resource&.id,
      ),
    )

    # Delegate to AuthenticationAuditWriter with best-effort semantics
    # This ensures audit failures do not block authentication
    AuthenticationAuditWriter.write(
      audit_class,
      event_id,
      resource: resource,
      actor: actor,
      ip_address: request_ip_address,
      context: context,
    )
  end

  def write_refresh_occurrence(event_type:, token_record:, reason:, device_source:)
    model_class = occurrence_model_class
    return unless model_class

    body = SecureRandom.uuid
    token_record_id = token_record&.public_id

    model_class.create!(
      body: body,
      event_type: event_type,
      status_id: 1,
      context: {
        host: request.host,
        request_id: request.request_id,
        ip_hash: occurrence_ip_hash,
        device_source: device_source,
        token_family_id: token_record&.refresh_token_family_id,
        token_id: token_record_id,
        generation: token_record&.refresh_token_generation,
        reason: reason,
      },
    )
  rescue StandardError => e
    Rails.logger.info(
      JitLogEvent.format(
        "#{resource_type}.occurrence.write_failed",
        event_type: event_type,
        reason: reason,
        error_class: e.class.name,
        error_message: e.message,
      ),
    )
  end

  def occurrence_model_class
    return ClientOccurrence if resource_type == "client"
    return OperatorOccurrence if resource_type == "operator"
    return VisitorOccurrence if resource_type == "visitor"

    nil
  end

  def occurrence_ip_hash
    ip = request_ip_address.to_s
    secret = Rails.app.creds.option(:OCCURRENCE_HMAC_SECRET).presence
    OpenSSL::HMAC.hexdigest("SHA256", secret, ip)
  end

  # ----------------------------------------------------------------------
  # 6-4) Refresh error handling and token/device guards
  # ----------------------------------------------------------------------
  def handle_missing_refresh_token(refresh_public_id)
    set_refresh_failure!(:unauthorized, "invalid_refresh_token")

    Rails.logger.info(
      JitLogEvent.format(
        "#{resource_type}.token.refresh.failed",
        refresh_token_id: refresh_public_id,
        reason: "token_not_found",
        ip_address: request_ip_address,
      ),
    )

    SignRiskEmitter.emit(
      "refresh_failed",
      user_token_id: refresh_public_id,
      ip: request&.remote_ip,
      user_agent: request&.user_agent,
      request_id: request&.request_id,
      meta: { reason: "token_not_found" },
    )

    nil
  end

  # Idle timeout on the refresh path: a session inactive longer than its
  # surface idle window can no longer refresh. This is an inactivity expiry, not
  # a security revocation, so the refresh is denied and the auth cookies are
  # cleared; the token family is left for ordinary expiry/cleanup rather than
  # hard-revoked.
  def handle_refresh_idle_timeout(_token_record, refresh_public_id)
    set_refresh_failure!(:unauthorized, "invalid_refresh_token")
    destroy_refresh_token_from_cookie
    clear_auth_cookies!

    Rails.logger.info(
      JitLogEvent.format(
        "#{resource_type}.token.refresh.failed",
        refresh_token_id: refresh_public_id,
        reason: "idle_timeout",
        ip_address: request_ip_address,
      ),
    )

    SignRiskEmitter.emit(
      "refresh_failed",
      user_token_id: refresh_public_id,
      ip: request&.remote_ip,
      user_agent: request&.user_agent,
      request_id: request&.request_id,
      meta: { reason: "idle_timeout" },
    )

    nil
  end

  def handle_inactive_resource(resource, refresh_public_id, token_record)
    set_inactive_resource_refresh_failure!(resource)
    notify_inactive_resource_refresh_failed(resource, refresh_public_id)
    emit_inactive_resource_refresh_failed(resource, refresh_public_id)
    revoke_inactive_refresh_token_family!(token_record)

    nil
  end

  def set_inactive_resource_refresh_failure!(resource)
    if resource.respond_to?(:deactivated?) && resource.deactivated?
      set_refresh_failure!(:forbidden, "withdrawal_required")
    else
      set_refresh_failure!(:unauthorized, "invalid_refresh_token")
    end
  end

  def handle_administrative_access_locked_refresh(resource, refresh_public_id, token_record)
    set_refresh_failure!(:forbidden, "administrative_access_locked")
    notify_inactive_resource_refresh_failed(resource, refresh_public_id)
    emit_inactive_resource_refresh_failed(resource, refresh_public_id)
    revoke_inactive_refresh_token_family!(token_record)

    nil
  end

  def notify_inactive_resource_refresh_failed(resource, refresh_public_id)
    Rails.logger.info(
      JitLogEvent.format(
        "#{resource_type}.token.refresh.failed",
        "#{resource_type}_id": resource&.id,
        refresh_token_id: refresh_public_id,
        reason: "#{resource_type}_inactive",
        ip_address: request_ip_address,
      ),
    )
  end

  def emit_inactive_resource_refresh_failed(resource, refresh_public_id)
    SignRiskEmitter.emit(
      "refresh_failed",
      **risk_actor_payload(resource&.id),
      user_token_id: refresh_public_id,
      ip: request&.remote_ip,
      user_agent: request&.user_agent,
      request_id: request&.request_id,
      meta: { reason: "#{resource_type}_inactive" },
    )
  end

  def revoke_inactive_refresh_token_family!(token_record)
    return if token_record.blank?

    token_record_connection_owner(token_record.class).connected_to(role: :writing) do
      now = Time.current
      family_id = token_record.refresh_token_family_id.to_s
      expiry_column = token_expiry_column(token_record.class)
      expiry_attrs = { expiry_column => now, :updated_at => now }
      expiry_attrs[:revoked_at] =
        now if expiry_column == :expired_at && token_record.class.column_names.include?("revoked_at")
      if family_id.present?
        scope = token_record.class.where(refresh_token_family_id: family_id)
        if token_record.class.column_names.include?("discarded_at")
          discarded_at = token_record.class.arel_table[:discarded_at]
          scope = scope.where(discarded_at.eq(nil).or(discarded_at.gt(now)))
        end
        # rubocop:disable Rails/SkipsModelValidations
        scope.update_all(expiry_attrs)
      elsif !token_expired_or_revoked?(token_record, expiry_column)
        token_record.update!(expiry_attrs)
      end
    end
  end

  def refreshable_resource?(resource, allow_suspended:)
    return false unless resource
    return true if resource.active?

    allow_suspended && resource.respond_to?(:suspended?) && resource.suspended?
  end

  def build_refreshed_session(resource, token_record, new_refresh_plain, previous_token_record: nil)
    @current_session_public_id = token_session_public_id(token_record)
    access_expires_at = access_token_expires_at_for(token_record)
    new_access_token = encode_refreshed_access_token(resource, token_record, access_expires_at)

    set_refresh_auth_cookies(token_record, new_access_token, new_refresh_plain, access_expires_at)
    best_effort_refresh_side_effect { emit_refresh_rotated(resource, token_record) }
    best_effort_refresh_side_effect { notify_token_refreshed(resource, token_record, previous_token_record) }
    best_effort_refresh_side_effect { record_audit(AUDIT_EVENTS[:token_refreshed], resource: resource) }
    # Detect a coarse-network change before the enforcer runs so an
    # ip_change_detected signal emitted here is scored in the same pass.
    best_effort_refresh_side_effect { detect_session_network_change!(token_record, resource) }
    best_effort_refresh_side_effect { SignRiskEnforcer.call(resource) }
    best_effort_refresh_side_effect { issue_dbsc_registration_header_for(token_record) }
    populate_current_attributes!(resource, nil)

    refreshed_session_payload(resource, token_record, new_access_token, new_refresh_plain, access_expires_at)
  end

  def emit_refresh_rotated(resource, token_record)
    SignRiskEmitter.emit(
      "refresh_rotated",
      **risk_actor_payload(resource.id),
      user_token_id: token_record.public_id,
      ip: request&.remote_ip,
      user_agent: request&.user_agent,
      request_id: request&.request_id,
    )
  end

  # Compare the request's coarse network (HMAC of the /24 IPv4 or /48 IPv6
  # network, never the full IP) against the value stored on the device session.
  # A change emits an `ip_change_detected` risk signal; the feature-flagged
  # engine rule then decides whether SignRiskEnforcer hard-revokes the session
  # (see adr/ip-anomaly-session-revocation.md). The stored fingerprint is
  # refreshed on every change (including the first observation) so a legitimate
  # move only costs one signal. Coarse granularity tolerates ordinary NAT/IP
  # churn; only a network-level change counts.
  def detect_session_network_change!(token_record, resource)
    device_session = token_record.try(:device_session)
    return if device_session.blank?
    return unless device_session.has_attribute?(:last_network_hmac)

    current = network_hmac_for_request
    return if current.blank?

    stored = device_session.last_network_hmac
    # This runs inside the transparent-refresh GET path, where the default connection
    # role is :reading. Persisting the refreshed network fingerprint requires the
    # :writing role, otherwise the UPDATE raises ActiveRecord::ReadOnlyError (caught by
    # best_effort_refresh_side_effect, but then the fingerprint never updates and an
    # ip_change_detected signal would re-fire on every request). Mirror the writing-role
    # wrapping used by issue_dbsc_challenge_for! and downgrade_pending_dbsc_to_nothing!.
    if stored != current
      ActiveRecord::Base.connected_to(role: :writing) do
        device_session.update_columns(last_network_hmac: current)
      end
    end

    return if stored.blank? || stored == current

    SignRiskEmitter.emit(
      "ip_change_detected",
      **risk_actor_payload(resource.id),
      user_token_id: token_record.public_id,
      ip: request&.remote_ip,
      user_agent: request&.user_agent,
      request_id: request&.request_id,
      meta: { reason: "network_change" },
    )
  end

  def network_hmac_for_request
    OccurrenceHmac.network_hmac(request_ip_address)
  rescue OccurrenceHmac::MissingSecretError
    nil
  end

  def notify_token_refreshed(resource, token_record, previous_token_record)
    Rails.logger.info(
      JitLogEvent.format(
        "#{resource_type}.token.refreshed",
        "#{resource_type}_id": resource.id,
        old_refresh_token_id: previous_token_record&.public_id || token_record.public_id,
        new_refresh_token_id: token_record.public_id,
        ip_address: request_ip_address,
      ),
    )
  end

  def refreshed_session_payload(resource, token_record, access_token, refresh_plain, access_expires_at)
    {
      access_token: access_token,
      refresh_token: refresh_plain,
      token_type: access_token_response_type(token_record),
      expires_in: expires_in_for(access_expires_at),
      user: resource,
      dbsc: dbsc_payload_for(token_record),
    }
  end

  def access_token_response_type(token_record)
    dpop_jkt = token_record_attribute(token_record, :dpop_jkt).presence ||
      token_record&.try(:device_session)&.dpop_jkt.presence
    dpop_jkt.present? ? "DPoP" : "Bearer"
  end

  def request_ip_address
    (respond_to?(:request, true) && request) ? request.remote_ip : nil
  end

  def handle_invalid_refresh_token_result(result, refresh_public_id, token_record = nil)
    handle_invalid_refresh_token_reason(result.reason.to_s, refresh_public_id, result.token || token_record)
  end

  def handle_invalid_refresh_token_reason(reason, refresh_public_id, token_record = nil, log_reason: reason)
    set_refresh_failure!(:unauthorized, "invalid_refresh_token")

    if reason == "refresh_token_reuse_detected"
      write_refresh_occurrence(
        event_type: "refresh_reuse_detected",
        token_record: token_record || find_refresh_token_record(refresh_public_id),
        reason: "reuse",
        device_source: refresh_binding_source(token_record),
      )
      Rails.logger.warn(
        # This is an internal diagnostic, not user-facing copy.
        # rubocop:disable I18n/RailsI18n/DecorateString
        "Refresh token reuse detected; clearing access and refresh cookies so the user can sign in again.",
        # rubocop:enable I18n/RailsI18n/DecorateString
      )
      begin
        destroy_refresh_token_from_cookie
      ensure
        clear_auth_cookies!
        reset_session if respond_to?(:reset_session)
      end
    end

    Rails.logger.info(
      JitLogEvent.format(
        "#{resource_type}.token.refresh.failed",
        refresh_token_id: refresh_public_id,
        reason: log_reason,
        ip_address: request_ip_address,
      ),
    )

    SignRiskEmitter.emit(
      "refresh_failed",
      user_token_id: refresh_public_id,
      ip: request&.remote_ip,
      user_agent: request&.user_agent,
      request_id: request&.request_id,
      meta: { reason: log_reason },
    )

    nil
  end

  def handle_refresh_binding_denied(token_record, refresh_public_id)
    reason = @refresh_dpop_reason || @refresh_dbsc_reason || "missing"
    event_type =
      if @refresh_dpop_reason.present?
        "refresh_dpop_denied"
      elsif token_record&.binding_method_dbsc?
        "refresh_dbsc_denied"
      else
        "refresh_binding_denied"
      end
    write_refresh_occurrence(
      event_type: event_type,
      token_record: token_record,
      reason: reason,
      device_source: refresh_binding_source(token_record),
    )

    revoke_refresh_session_after_dbsc_failure!(token_record) if @refresh_dbsc_reason.present?
    set_refresh_failure!(:unauthorized, "invalid_refresh_token")
    destroy_refresh_token_from_cookie
    clear_auth_cookies!
    reset_session if @refresh_dbsc_reason.present? && respond_to?(:reset_session)

    Rails.logger.info(
      JitLogEvent.format(
        "#{resource_type}.token.refresh.failed",
        refresh_token_id: refresh_public_id,
        reason: binding_failure_reason(reason, token_record),
        ip_address: request_ip_address,
      ),
    )

    nil
  end

  def handle_refresh_error(exception, refresh_public_id, resource)
    set_refresh_failure!(:unauthorized, "invalid_refresh_token")

    Rails.logger.info(
      JitLogEvent.format(
        "#{resource_type}.token.refresh.error",
        "#{resource_type}_id": resource&.id,
        refresh_token_id: refresh_public_id,
        error_message: exception.message,
        ip_address: request_ip_address,
      ),
    )

    SignRiskEmitter.emit(
      "refresh_failed",
      **risk_actor_payload(resource&.id),
      user_token_id: refresh_public_id,
      ip: request&.remote_ip,
      user_agent: request&.user_agent,
      request_id: request&.request_id,
      meta: { error_class: exception.class.name },
    )

    nil
  end

  def handle_restricted_refresh_rejected(token_record, refresh_public_id)
    restricted_expires_at = token_record.discarded_at if token_record.respond_to?(:discarded_at)
    expired = restricted_expires_at.present? && restricted_expires_at <= Time.current

    if expired && !token_record.revoked?
      token_record_connection_owner(token_record.class).connected_to(role: :writing) do
        token_record.revoke!
      end
      Rails.logger.info(
        JitLogEvent.format(
          "session.restricted.expired",
          user_token_id: token_record.public_id,
          "#{resource_type}_id": token_record.public_send("#{token_resource_prefix}_id"),
        ),
      )
    end

    set_refresh_failure!(:forbidden, "restricted_session")

    Rails.logger.info(
      JitLogEvent.format(
        "#{resource_type}.token.refresh.failed",
        refresh_token_id: refresh_public_id,
        reason: expired ? "restricted_expired" : "restricted_session",
        ip_address: request_ip_address,
      ),
    )

    nil
  end

  def find_refresh_token_record(refresh_public_id)
    return nil if refresh_public_id.blank?

    find_logic = -> { token_class.find_by(public_id: refresh_public_id) }
    token_record_connection_owner.connected_to(role: :reading, &find_logic)
  end

  def set_refresh_failure!(status, code)
    @refresh_failure_status = status
    @refresh_failure_code = code
  end

  def clear_refresh_failure!
    @refresh_failure_status = nil
    @refresh_failure_code = nil
    @refresh_dpop_reason = nil
    @refresh_dbsc_reason = nil
    @refresh_dbsc_verified = false
  end

  # Idle timeout guard for the refresh path. A refresh is allowed only while the
  # session's last activity (last_used_at, falling back to created_at) is within
  # the surface idle window. Activity is recorded per-request by the resolver
  # (touch_session_activity!) and on each rotation, so an actively used session
  # never trips this; a session left idle past the window can no longer refresh.
  # A missing token or missing timestamps fail open here so the existing
  # invalid-token and absolute-lifetime checks remain authoritative.
  def refresh_idle_allowed?(token_record)
    return true if token_record.blank?

    reference = token_record_attribute(token_record, :last_used_at).presence ||
      (token_record.respond_to?(:created_at) ? token_record.created_at : nil)
    return true if reference.blank?

    reference >= Time.current - ::SecurityTokenLifetimes.idle_ttl_for(resource_type)
  end

  def refresh_dpop_allowed?(token_record)
    expected_jkt = token_record_attribute(token_record, :dpop_jkt).presence ||
      token_record&.try(:device_session)&.dpop_jkt.presence
    return true if expected_jkt.blank?

    proof = request.headers["DPoP"]
    if proof.blank?
      @refresh_dpop_reason = "missing"
      return false
    end

    result = DpopProofVerifier.new(
      proof_jwt: proof,
      request_method: request.request_method,
      request_uri: request.original_url,
      resource_type: resource_type,
    ).call
    unless result.valid?
      @refresh_dpop_reason = result.error
      return false
    end

    unless secure_compare?(expected_jkt, result.jkt)
      @refresh_dpop_reason = "jkt_mismatch"
      return false
    end

    true
  end

  def refresh_binding_allowed?(token_record)
    return false if token_record&.respond_to?(:device_session) && token_record.device_session&.revoked?
    return false unless device_session_refresh_allowed?(token_record)
    return refresh_dbsc_allowed?(token_record) if token_record&.binding_method_dbsc?

    # Any token reaching here is not DBSC-bound. DPoP (if present) is enforced
    # separately by refresh_dpop_allowed?, which is ANDed with this check at the
    # call site. Accepting an otherwise-unbound token is a deliberate, temporary
    # LEGACY/compatibility allowance (browser sign-in issues LEGACY tokens; the
    # OIDC token endpoint issues NOTHING tokens) and NOT a security guarantee.
    # Routing it through a named predicate keeps the allowance visible in code
    # and makes inconsistent binding state fail closed instead of silently
    # passing as it did before.
    legacy_unbound_refresh_allowed?(token_record)
  end

  # Explicit, narrow LEGACY/compatibility allowance for refresh tokens that are
  # not DBSC-bound. This intentionally keeps today's legitimately-unbound
  # populations (LEGACY browser sessions, NOTHING OIDC tokens) working while a
  # full DBSC/DPoP rollout is in progress. It is temporary legacy behavior, not
  # a guarantee -- see the binding rollout in adr/ before relying on it.
  #
  # Fails closed on contradictory state: a token whose binding method is not
  # DBSC must not also advertise a DBSC lifecycle status. Such a token would
  # previously have slipped through the old implicit `return true`.
  def legacy_unbound_refresh_allowed?(token_record)
    # An unknown token cannot be evaluated for binding; let the downstream
    # token-validity check reject it as an invalid refresh token rather than
    # masking it as a binding denial.
    return true if token_record.blank?

    # Only genuinely non-DBSC binding methods are eligible here.
    return false unless token_record.binding_method_nothing? || token_record.binding_method_legacy?

    # Browser-login tokens are issued LEGACY + PENDING (DBSC registration
    # offered). A capable browser completes registration and becomes
    # DBSC/ACTIVE, which is handled earlier in refresh_binding_allowed? and
    # never reaches here. A token still PENDING at refresh time means
    # registration has not completed: allow the refresh (do not lock out a
    # non-DBSC browser), and once the registration challenge has expired without
    # a proof, downgrade it to an explicit NOTHING fallback so its binding state
    # is consistent and observable. Within the grace window leave it PENDING so
    # a capable browser can still bind on a later interaction.
    if token_record.binding_method_legacy? && token_record.dbsc_status_pending?
      downgrade_pending_dbsc_to_nothing!(token_record) if dbsc_registration_challenge_expired?(token_record)
      return true
    end

    # A non-DBSC token in any other DBSC lifecycle state (active/failed/revoke)
    # is inconsistent; fail closed instead of accepting it unbound.
    return false unless token_record.dbsc_status_nothing?

    true
  end

  # A DBSC registration challenge is considered expired (registration not
  # completed in time) once DBSC_COOKIE_TTL has elapsed since it was issued. A
  # token with no recorded challenge timestamp has nothing left to wait for, so
  # it is treated as expired too.
  def dbsc_registration_challenge_expired?(token_record)
    issued_at = token_record.try(:dbsc_challenge_issued_at)
    return true if issued_at.blank?

    issued_at <= Time.current - DBSC_COOKIE_TTL
  end

  def downgrade_pending_dbsc_to_nothing!(token_record)
    ActiveRecord::Base.connected_to(role: :writing) do
      token_record.downgrade_dbsc_status_to_nothing!
    end
  end

  def device_session_refresh_allowed?(token_record)
    device_session = token_record&.try(:device_session)
    return true if device_session.blank?
    return false if device_session.revoked?
    return true if @refresh_dbsc_verified && device_session.dbsc_bound?
    return true unless device_session.dbsc_bound?

    session_id = request.headers[AuthIoKeys::Headers::DBSC_SESSION_ID]
    proof = request.headers[AuthIoKeys::Headers::DBSC_RESPONSE]
    if session_id.blank? || proof.blank?
      @refresh_dbsc_reason = "missing_proof"
      return false
    end

    if device_session.dbsc_session_id_digest.present?
      presented_digest = device_session.class.digest_session_identifier(DbscHeaderParser.string_value(session_id))
      unless secure_compare?(device_session.dbsc_session_id_digest, presented_digest)
        @refresh_dbsc_reason = "session_id_mismatch"
        return false
      end
    end

    result = DbscVerificationService.call(
      record: token_record,
      session_id: session_id,
      proof: proof,
      expected_audience: token_dbsc_url,
    )
    unless result[:ok]
      @refresh_dbsc_reason = result[:error_code].presence || "invalid_proof"
      return false
    end

    clear_dbsc_challenge_after_refresh_verification!(token_record)
    @refresh_dbsc_verified = true
    true
  end

  def refresh_dbsc_allowed?(token_record)
    return true if token_record.blank?
    return false unless token_record.dbsc_status_active?

    dbsc_cookie = cookies[DBSC_COOKIE_KEY].to_s.presence
    if dbsc_cookie.blank?
      @refresh_dbsc_reason = "missing_bound_cookie"
      return false
    end

    if token_record.dbsc_session_id.to_s.blank? || token_record.dbsc_session_id != dbsc_cookie
      @refresh_dbsc_reason = "session_id_mismatch"
      return false
    end

    true
  end

  def revoke_refresh_session_after_dbsc_failure!(token_record)
    return if token_record.blank?

    token_record.class.transaction do
      if token_record.respond_to?(:device_session) && token_record.device_session.present?
        token_record.device_session.revoke!(reason: "dbsc_refresh_failed")
        token_record.class.where(device_session_id: token_record.device_session_id).find_each do |session_token|
          session_token.revoke! if session_token.respond_to?(:revoke!) && !session_token.revoked?
        end
      elsif token_record.respond_to?(:revoke!) && !token_record.revoked?
        token_record.revoke!
      end
    end
  rescue ActiveRecord::ActiveRecordError => e
    Rails.logger.info(
      JitLogEvent.format(
        "auth.refresh.dbsc_logout_failed",
        token_id: token_record&.try(:public_id),
        error_class: e.class.name,
        error_message: e.message,
      ),
    )
  end

  def clear_dbsc_challenge_after_refresh_verification!(token_record)
    token_record.class.find(token_record.id).update!(
      dbsc_challenge: nil,
      dbsc_challenge_issued_at: nil,
    )
    token_record.dbsc_challenge = nil if token_record.respond_to?(:dbsc_challenge=)
    token_record.dbsc_challenge_issued_at = nil if token_record.respond_to?(:dbsc_challenge_issued_at=)
  end

  def refresh_dbsc_source
    session_present = request.headers[AuthIoKeys::Headers::DBSC_SESSION_ID].to_s.present?
    response_present = request.headers[AuthIoKeys::Headers::DBSC_RESPONSE].to_s.present?
    return "both" if session_present && response_present
    return "session_id" if session_present
    return "response" if response_present

    "none"
  end

  def refresh_binding_source(token_record)
    return "dpop" if @refresh_dpop_reason.present?
    return refresh_dbsc_source if token_record&.binding_method_dbsc?

    "none"
  end

  def binding_failure_reason(reason, token_record)
    return "dpop_#{reason}" if @refresh_dpop_reason.present?

    prefix = token_record&.binding_method_dbsc? ? "dbsc" : "binding"
    "#{prefix}_#{reason}"
  end

  def load_current_resource
    return nil unless respond_to?(:request, true) && request.present?

    resource = load_from_token
    return nil if authentication_credentials_invalid?
    return @current_resource if resource.blank? && @current_resource.present?
    return nil if resource_withdrawn?(resource)
    return resource if resource.present?
    return nil if controller_path.end_with?("/edge/v0/token/refreshes")
    return nil unless transparent_refresh_allowed?

    refresh_plain = cookies[REFRESH_COOKIE_KEY]
    return nil if refresh_plain.blank?

    refresh_result = attempt_transparent_refresh!(refresh_plain)
    return nil unless refresh_result

    @current_resource = refresh_result[:user]
    return nil if resource_withdrawn?(@current_resource)

    @current_resource
  end

  def load_from_token
    access_token = extract_access_token(ACCESS_COOKIE_KEY)
    request_host = request&.host
    return nil if request_host.blank?

    authorization_scheme = AuthAuthorizationHeader.scheme(request)
    dpop_proof = request.headers["DPoP"]

    result = AuthenticationCurrentResourceResolver.new(
      access_token: access_token,
      request_host: request_host,
      resource_type: resource_type,
      resource_class: resource_class,
      token_class: token_class,
      authorization_scheme: authorization_scheme,
      dpop_proof: dpop_proof,
      request_method: request.request_method,
      request_uri: request.original_url,
      jwt_issuer_id: auth_jwt_issuer_id,
    ).call

    if result.resource.blank? && (authorization_scheme.to_s.casecmp?("DPoP") || dpop_proof.present?)
      response.headers["DPoP-Nonce"] =
        DpopNonceService.generate(resource_type: resource_type) if defined?(DpopNonceService)
    end

    remember_authentication_resolution!(
      result, authorization_scheme: authorization_scheme,
              access_token: access_token,
    )
    emit_actor_mismatch_event(result.payload) if result.failure_reason == :actor_mismatch
    @current_session_public_id = result.session_public_id if result.session_public_id.present?
    @current_token_public_id = result.token_public_id if result.token_public_id.present?

    populate_current_attributes!(result.resource, result.payload) if result.resource.present?

    result.resource
  end

  def remember_authentication_resolution!(result, authorization_scheme:, access_token:)
    @current_authentication_failure_reason = result.failure_reason
    @current_authentication_credentials_present =
      access_token.present? ||
      authorization_scheme.present? ||
      result.failure_reason != :blank_access_token ||
      result.payload.present?
  end

  def authentication_credentials_invalid?
    @current_authentication_credentials_present && @current_authentication_failure_reason.present?
  end

  # Populate Actor.* attributes from JWT payload after successful authentication
  def populate_current_attributes!(resource, payload)
    return if resource.blank?

    actor_type =
      case resource_type
      when "operator" then :operator
      when "visitor" then :visitor
      else :client
      end
    authn = Actor::Authentication.new(
      login_public_id: @current_session_public_id,
      access_claims: payload,
      acr: payload&.dig("acr"),
      amr: payload&.dig("amr"),
      actor_type: actor_type,
      actor_id: resource.id,
      restricted: current_session_restricted_for_authn,
    )
    surface = CoreSurface.current(request) if respond_to?(:request, true) && request.present?
    attributes = {
      actor: resource,
      actor_type: actor_type,
      authn: authn,
      authz: Actor::Authz.new(
        policy_user: resource,
        token_claims: authn.access_claims,
        surface: surface,
      ),
    }
    attributes[:tld] = surface if surface.present?

    Actor.install_context!(**attributes)
  end

  def emit_actor_mismatch_event(payload)
    actual_resource_type = AuthenticationToken.extract_resource_type(payload)
    sub = AuthenticationToken.extract_subject(payload)

    Rails.logger.info(
      JitLogEvent.format(
        "authentication.actor_mismatch",
        expected: resource_type,
        actual: actual_resource_type,
        subject: sub,
        ip_address: request_ip_address,
      ),
    )

    SignRiskEmitter.emit(
      "actor_mismatch",
      **risk_actor_payload(sub),
      ip: request&.remote_ip,
      user_agent: request&.user_agent,
      request_id: request&.request_id,
      meta: { expected: resource_type, actual: actual_resource_type },
    )
  end

  # Returns { user_id: id } or { staff_id: id } based on resource_type.
  # Used by Risk::Emitter to route events to the correct occurrence table.
  def risk_actor_payload(id)
    case resource_type
    when "operator"
      { staff_id: id }
    when "visitor"
      { visitor_id: id }
    else
      { user_id: id }
    end
  end

  def resource_withdrawn?(resource)
    return false unless resource&.respond_to?(:withdrawn?)
    return false if respond_to?(:withdrawal_restricted_resource?, true) && withdrawal_restricted_resource?(resource)

    resource.withdrawn?
  end

  def administratively_locked_resource?(resource)
    AuthenticationCurrentResourceResolver.administratively_locked?(resource)
  end

  def destroy_refresh_token_from_cookie
    token_value = cookies[REFRESH_COOKIE_KEY]
    return unless token_value

    public_id, = token_class.parse_refresh_token(token_value)
    return unless public_id

    resource = defined?(@current_resource) ? @current_resource : nil
    AuthenticationLogoutCurrentSession.call(
      current: Actor,
      resource: resource,
      token_class: token_class,
      session_public_id: public_id,
      reason: "refresh_token_invalidated",
    )
  rescue ActiveRecord::RecordNotDestroyed => e
    Rails.logger.info(
      JitLogEvent.format(
        "#{resource_type}.token.destroy.failed",
        token_id: public_id,
        error_message: e.message,
        ip_address: request_ip_address,
      ),
    )
  end

  # Handles session expiry by redirecting with appropriate message
  #
  # @param redirect_path [String, Symbol] Where to redirect
  # @param message_key [String] Translation key for the expiry message
  def handle_session_expiry(redirect_path, message_key)
    redirect_params = { notice: t(message_key) }
    # Preserve redirect parameter if present
    default_pt_key = DEFAULT_PT_SESSION_KEY
    redirect_params[AuthIoKeys::Params::PT] = session[default_pt_key] if session[default_pt_key].present?
    redirect_to(redirect_path, redirect_params)
  end

  # ======================================================================
  # 7) Policy/domain decisions
  # ======================================================================
  # --- Policy enforcement methods ---

  def verify_private_action_authorized!
    return unless self.class.authentication_mode_for(action_name) == :private

    verify_authorized
  end

  def enforce_access_policy!
    mode = self.class.authentication_mode_for(action_name)
    policy = policy_for_authentication_mode(mode)
    options = access_policy_options_for(action_name)
    context = access_policy_context(policy, options)

    Rails.logger.debug(
      JitLogEvent.format(
        "auth.policy.resolved",
        authentication_mode: mode,
        policy: policy,
        controller: self.class.name,
        action: action_name,
        rules_count: self.class.access_policy_rules.size,
        authentication_mode_rules_count: self.class.local_authentication_mode_rules.size,
      ),
    )

    case mode
    when :deny_all
      enforce_authentication_deny_all!(options)
    when :bare
      access_policy_allows?(:public_strict?, context)
    when :open
      return enforce_authentication_open!(options) if authentication_credentials_invalid?

      access_policy_allows?(:public_strict?, context)
    when :private
      return true if access_policy_allows?(:auth_required?, context)

      enforce_authentication_private!(options)
    when :guest
      return true if access_policy_allows?(:guest_only?, context)

      enforce_authentication_guest!(options)
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
      logged_in: respond_to?(:logged_in?) && logged_in?,
      current_resource_deactivated: access_policy_current_resource_deactivated?,
    )
  end

  def access_policy_current_resource_deactivated?
    return false unless respond_to?(:current_resource)

    resource = current_resource
    resource.respond_to?(:deactivated?) && resource.deactivated?
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
    resolve_authentication_mode_rule_for(action)&.fetch(:options, {}) ||
      resolve_access_policy_for(action)&.fetch(:options, {}) ||
      {}
  end

  def resolve_authentication_mode_rule_for(action)
    action = action.to_s

    self.class.local_authentication_mode_rules.reverse_each do |rule|
      next if rule[:only].present? && rule[:only].exclude?(action)
      next if rule[:except].present? && rule[:except].include?(action)

      return rule
    end

    nil
  end

  def resolve_access_policy_for(action)
    action = action.to_s

    # Last rule wins so controller-wide policies can be overridden per action.
    rules = self.class.access_policy_rules
    return nil if rules.blank?

    rules.reverse_each do |rule|
      next if rule[:only].present? && rule[:only].exclude?(action)
      next if rule[:except].present? && rule[:except].include?(action)

      return rule
    end

    nil
  end

  # --- Behavior implementation (align with your auth stack) ---

  def enforce_authentication_open!(_options = {})
    return true unless authentication_credentials_invalid?
    return true if detach_stale_open_session_credentials!

    Rails.logger.info(
      JitLogEvent.format(
        "auth.open.invalid_credentials",
        reason: @current_authentication_failure_reason,
        controller: self.class.name,
        action: action_name,
      ),
    )
    render plain: I18n.t("auth.session_expired"), status: :unauthorized
    false
  end

  # Leftover access/refresh cookies after family revoke (refresh reuse) or expiry still look like
  # "invalid credentials" on :open HTML endpoints such as /oauth/authorize. Detach them so the
  # request continues as anonymous and the user can sign in again, instead of a 401 that cannot
  # start the ceremony. JSON and binding failures stay on the failure path.
  def detach_stale_open_session_credentials!
    return false unless request.format.html?
    return false unless %i(token_session_not_found token_decode_failed).include?(
      @current_authentication_failure_reason,
    )

    Rails.logger.warn(
      "Stale session credentials presented after refresh token reuse or expiry; " \
      "clearing auth cookies so sign-in can proceed.",
    )
    begin
      destroy_refresh_token_from_cookie if respond_to?(:destroy_refresh_token_from_cookie, true)
    ensure
      clear_auth_cookies! if respond_to?(:clear_auth_cookies!, true)
      reset_session if respond_to?(:reset_session)
      @current_authentication_credentials_present = false
      @current_authentication_failure_reason = nil
    end
    true
  end

  def enforce_authentication_deny_all!(_options = {})
    # Developer-facing internal raise; not user-facing, so not translated.
    # rubocop:disable I18n/RailsI18n/DecorateString
    raise MissingPolicyError,
          "Denied by default authentication mode for #{self.class.name}##{action_name}. " \
          "Declare a concrete authentication mode before exposing this endpoint."
    # rubocop:enable I18n/RailsI18n/DecorateString
  end

  def enforce_authentication_private!(options = {})
    # Example: use AuthenticationBase logged_in? / current_resource.
    return true if respond_to?(:logged_in?) && logged_in?

    # Branch HTML vs API (or delegate to your responder).
    if request.format.json? || options[:request_format] == :json
      handle_auth_required_json(options)
    else
      handle_auth_required_html(options)
    end
  end

  def enforce_authentication_guest!(options = {})
    # Guest-only policy: block logged-in users.
    return true unless respond_to?(:logged_in?) && logged_in?

    # Exception: deactivated users should be handled by withdrawal gate, not guest_only
    if current_resource.respond_to?(:deactivated?) && current_resource.deactivated?
      return true
    end

    if request.format.json? || options[:request_format] == :json
      handle_guest_only_json(options)
    else
      handle_guest_only_with_status_checks(options)
    end
  end

  def create_login_token_record(resource, token_kind_id, token_status_id: nil, dpop_jkt: nil,
                                established_authentication_method: nil, authentication_context: nil)
    token_record_connection_owner.connected_to(role: :writing) do
      token_attributes = { resource_foreign_key => resource.id }
      token_attributes[:dpop_jkt] = dpop_jkt if dpop_jkt.present?
      # Determine kind column based on resource type (user_token_kind_id or staff_token_kind_id)
      kind_column = "#{token_resource_prefix}_token_kind_id"
      if token_class.column_names.include?(kind_column)
        ensure_token_kind_exists!(token_kind_id)
        token_attributes[kind_column] = token_kind_id
      end

      # adr/unified-enforcement.md, Session attribution: nil is a defined, safe
      # state, never backfilled with a guess.
      if established_authentication_method.present? &&
          token_class.column_names.include?("established_authentication_method")
        token_attributes[:established_authentication_method] = established_authentication_method
      end

      # The authentication context is the durable authority for Restricted Mode.
      # It is written once, at session issue, and never updated afterwards:
      # there is no supported transition between Normal and Emergency inside a
      # session (docs/security/org-emergency-access.md).
      if authentication_context.present?
        unless token_class.column_names.include?("authentication_context")
          raise ArgumentError,
                "#{token_class.name} cannot record an authentication context; " \
                "Emergency Access is available on surfaces with the column only"
        end

        token_attributes[:authentication_context] =
          AuthenticationContextValue.for(authentication_context).to_s
      end

      token_attributes.merge!(default_status_token_attributes(token_status_id))
      token_attributes.merge!(default_dbsc_token_attributes(token_kind_id))
      token_attributes.merge!(scheduled_login_token_attributes)
      ensure_login_token_reference_data!(token_attributes)

      token_class.create!(token_attributes)
    end
  rescue ActiveRecord::RecordInvalid => e
    raise ConcurrentSessionLimitExceededError, e.message if concurrent_session_limit_validation_error?(e)

    raise
  end

  # LEGACY here means "no DBSC binding". Non-DBSC sessions are ordinary
  # sessions and must not fall back to a pseudo device guarantee.
  #
  # Browser-login tokens are eligible for DBSC: issue them LEGACY + PENDING so
  # the "registration offered / awaiting binding" state is explicit and
  # time-boxed. issue_dbsc_registration_header_for offers the challenge on the
  # same response (login and refresh); a capable browser then upgrades to
  # DBSC/ACTIVE via DbscRegistrationService, while a browser that never binds is
  # downgraded to an explicit NOTHING fallback on its first refresh after the
  # challenge expires (see legacy_unbound_refresh_allowed?). Native-app tokens
  # (CLIENT_IOS/ANDROID) cannot perform browser DBSC, so they stay NOTHING.
  # OIDC token-endpoint tokens never reach this path (no interactive browser).
  def default_dbsc_token_attributes(token_kind_id = nil)
    pending = dbsc_registration_eligible_kind?(token_kind_id)
    case resource_type
    when "client"
      {
        user_token_binding_method_id: ClientTokenBindingMethod::LEGACY,
        user_token_dbsc_status_id: pending ? ClientTokenDbscStatus::PENDING : ClientTokenDbscStatus::NOTHING,
      }
    when "operator"
      {
        staff_token_binding_method_id: OperatorTokenBindingMethod::LEGACY,
        staff_token_dbsc_status_id: pending ? OperatorTokenDbscStatus::PENDING : OperatorTokenDbscStatus::NOTHING,
      }
    when "visitor"
      {
        visitor_token_binding_method_id: VisitorTokenBindingMethod::LEGACY,
        visitor_token_dbsc_status_id: pending ? VisitorTokenDbscStatus::PENDING : VisitorTokenDbscStatus::NOTHING,
      }
    else
      {}
    end
  end

  # Only interactive browser sessions can complete DBSC registration (it relies
  # on the Sec-Session-Registration/Response header exchange). Native-app and
  # unknown kinds are not offered PENDING.
  def dbsc_registration_eligible_kind?(token_kind_id)
    return false if token_kind_id.blank?

    case resource_type
    when "client" then token_kind_id == ClientTokenKind::BROWSER_WEB
    when "operator" then token_kind_id == OperatorTokenKind::BROWSER_WEB
    when "visitor" then token_kind_id == VisitorTokenKind::BROWSER_WEB
    else false
    end
  end

  def default_status_token_attributes(token_status_id = nil)
    case resource_type
    when "client"
      { user_token_status_id: token_status_id.presence || ClientTokenStatus::ACTIVE }
    when "operator"
      { staff_token_status_id: token_status_id.presence || OperatorTokenStatus::ACTIVE }
    when "visitor"
      { visitor_token_status_id: token_status_id.presence || VisitorTokenStatus::ACTIVE }
    else
      {}
    end
  end

  def resolve_token_kind_id(raw_kind_id)
    return raw_kind_id unless raw_kind_id.is_a?(String)

    kind_column = "#{token_resource_prefix}_token_kind_id"
    return raw_kind_id unless token_class.columns_hash[kind_column]&.type == :integer

    kind_model = token_kind_model
    if kind_model.column_names.include?("code")
      begin
        return kind_model.find_by!(code: raw_kind_id).id
      rescue ActiveRecord::RecordNotFound
        Rails.logger.error(
          JitLogEvent.format(
            "auth.token.kind_missing",
            kind_model: kind_model.name,
            code: raw_kind_id,
            resource_type: resource_type,
          ),
        )
        raise ActiveRecord::RecordNotFound,
              "Missing #{kind_model.name} code=#{raw_kind_id} for #{resource_type} login"
      end
    end

    resolved =
      case [resource_type, raw_kind_id]
      when ["operator", "BROWSER_WEB"] then OperatorTokenKind::BROWSER_WEB
      when ["operator", "CLIENT_IOS"] then OperatorTokenKind::CLIENT_IOS
      when ["operator", "CLIENT_ANDROID"] then OperatorTokenKind::CLIENT_ANDROID
      when ["client", "BROWSER_WEB"] then ClientTokenKind::BROWSER_WEB
      when ["client", "CLIENT_IOS"] then ClientTokenKind::CLIENT_IOS
      when ["client", "CLIENT_ANDROID"] then ClientTokenKind::CLIENT_ANDROID
      when ["visitor", "BROWSER_WEB"] then VisitorTokenKind::BROWSER_WEB
      when ["visitor", "CLIENT_IOS"] then VisitorTokenKind::CLIENT_IOS
      when ["visitor", "CLIENT_ANDROID"] then VisitorTokenKind::CLIENT_ANDROID
      end

    return resolved if resolved

    raise ActiveRecord::RecordNotFound, "Missing #{kind_model.name} for code=#{raw_kind_id}"
  end

  def ensure_token_kind_exists!(token_kind_id)
    return if token_kind_id.blank?

    kind_model = token_kind_model
    token_reference_connection_model(kind_model).connected_to(role: :writing) do
      if kind_model.respond_to?(:ensure_defaults!)
        kind_model.ensure_defaults!
      else
        kind_model.find_or_create_by!(id: token_kind_id)
      end
    end
  rescue ActiveRecord::RecordNotFound
    Rails.logger.error(
      JitLogEvent.format(
        "auth.token.kind_missing",
        kind_model: kind_model.name,
        id: token_kind_id,
        resource_type: resource_type,
      ),
    )
    raise ActiveRecord::RecordNotFound,
          "Missing #{kind_model.name} id=#{token_kind_id} for #{resource_type} login"
  end

  def ensure_login_token_reference_data!(token_attributes)
    login_token_reference_models.each do |column_name, model|
      id = token_attributes[column_name]
      next if id.blank?

      token_reference_connection_model(model).connected_to(role: :writing) do
        if model.respond_to?(:ensure_defaults!)
          model.ensure_defaults!
        else
          model.find_or_create_by!(id: id)
        end
      end
    end
  end

  def token_reference_connection_model(model)
    return AppTicketRecord if model <= AppTicketRecord
    return ComTicketRecord if model <= ComTicketRecord

    OrgTicketRecord
  end

  def login_token_reference_models
    case resource_type
    when "client"
      {
        user_token_binding_method_id: ClientTokenBindingMethod,
        user_token_dbsc_status_id: ClientTokenDbscStatus,
        user_token_kind_id: ClientTokenKind,
        user_token_status_id: ClientTokenStatus,
      }
    when "operator"
      {
        staff_token_binding_method_id: OperatorTokenBindingMethod,
        staff_token_dbsc_status_id: OperatorTokenDbscStatus,
        staff_token_kind_id: OperatorTokenKind,
        staff_token_status_id: OperatorTokenStatus,
      }
    when "visitor"
      {
        visitor_token_binding_method_id: VisitorTokenBindingMethod,
        visitor_token_dbsc_status_id: VisitorTokenDbscStatus,
        visitor_token_kind_id: VisitorTokenKind,
        visitor_token_status_id: VisitorTokenStatus,
      }
    else
      {}
    end
  end

  def token_kind_model
    case resource_type
    when "client" then ClientTokenKind
    when "operator" then OperatorTokenKind
    when "visitor" then VisitorTokenKind
    else
      raise ActiveRecord::RecordNotFound, "Missing token kind model for resource_type=#{resource_type}"
    end
  end

  def token_resource_prefix
    return "staff" if resource_type == "operator"
    return "user" if resource_type == "client"

    resource_type
  end

  # ----------------------------------------------------------------------
  # 7-1) MFA/session-limit domain decisions
  # ----------------------------------------------------------------------
  def check_totp_requirement(resource)
    return unless mfa_required_for?(resource)

    set_pending_mfa!(resource: resource, primary: "mfa")
    { status: :mfa_required }
  end

  def set_pending_mfa!(resource:, primary:, pt: nil, ri: nil, auth_method: nil,
                       established_authentication_method: nil)
    issued_at = Time.current.to_i
    expires_at = pending_mfa_ttl.from_now.to_i
    session[:pending_mfa] = {
      "public_id" => SecureRandom.hex(16),
      "user_id" => resource.id,
      "resource_type" => resource_type,
      "primary" => primary.to_s,
      "auth_method" => auth_method.to_s.presence || primary.to_s,
      "established_authentication_method" => established_authentication_method.presence,
      "pt" => pt.presence,
      "ri" => ri.to_s.presence,
      "issued_at" => issued_at,
      "expires_at" => expires_at,
    }
    # No per-ceremony attempt counter is kept here. A session-scoped counter is not
    # a control: an attacker discards the session and starts a fresh one. Second-factor
    # guessing is bounded per account by the "*_create_account" rate_limit rules on the
    # TOTP challenge and secret-credential controllers, which are keyed on the
    # pending-MFA user id and backed by the shared rate-limit store.
    # Backward compatibility for existing controllers still using mfa_user_id.
    session[:mfa_user_id] = resource.id
  end

  def pending_mfa
    raw = session[:pending_mfa]
    return nil unless raw.is_a?(Hash)

    raw.with_indifferent_access
  end

  def pending_mfa_ttl
    10.minutes
  end

  def pending_mfa_valid?
    data = pending_mfa
    return false unless data

    expires_at = epoch_seconds(data[:expires_at])
    if expires_at.positive?
      return false if Time.current.to_i >= expires_at
    else
      issued_at = epoch_seconds(data[:issued_at])
      return false if issued_at <= 0
      return false if Time.zone.at(issued_at) < pending_mfa_ttl.ago
    end

    true
  end

  def pending_mfa_user
    return nil unless pending_mfa_valid?

    user_id = pending_mfa[:user_id]
    return nil if user_id.blank?

    klass = respond_to?(:resource_class, true) ? resource_class : ::Client
    klass.find_by(id: user_id)
  end

  def clear_pending_mfa!
    session.delete(:pending_mfa)
    session.delete(:mfa_user_id)
  end

  # adr/unified-enforcement.md, JWT AMR: derives `amr` from
  # `established_authentication_method` (Session attribution) when the session
  # record carries one, falling back to the legacy token_kind_id-based mapping
  # only when it does not (legacy/NULL sessions, or non-interactive token
  # kinds). RFC 8176 has no registered value distinguishing google/apple, so
  # the existing provider-specific extension values are unchanged; telephone,
  # totp, and entra are now populated instead of falling through to `[]` as
  # they did previously.
  ESTABLISHED_AUTHENTICATION_METHOD_AMR_MAP = {
    "email" => ["email_otp"],
    "telephone" => ["sms"],
    "secret" => ["passcode"],
    "passkey" => ["passkey"],
    "totp" => ["otp"],
    "google" => ["google"],
    "apple" => ["apple"],
    "entra" => ["entra_id"],
  }.freeze

  def normalize_amr(token_kind_id, token_record: nil)
    established_method = token_record.try(:established_authentication_method)
    mapped = ESTABLISHED_AUTHENTICATION_METHOD_AMR_MAP[established_method.to_s]
    return mapped if mapped

    case token_kind_id.to_s
    when "email" then ["email_otp"]
    when "passkey" then ["passkey"]
    when "google" then ["google"]
    when "apple" then ["apple"]
    when "secret_credential" then ["passcode"]
    else []
    end
  end

  # Completes login after successful MFA verification.
  # Consumes the pending MFA session, logs in the user, and returns a result hash
  # with redirect information.
  #
  # @param user [User] the user to log in
  # @return [Hash] result with :status, :redirect_path, etc.
  def finalize_mfa_login!(user)
    pt = pending_mfa&.dig(:pt)
    pending_mfa_auth_method = pending_mfa&.dig(:auth_method)
    pending_mfa_established_authentication_method = pending_mfa&.dig(:established_authentication_method)
    cycle = pending_mfa_sign_in_flow_for(user)
    clear_pending_mfa!

    result = pending_sign_in_result_after_primary!(
      user,
      pt: pt,
      record_login_audit: true,
      token_kind_id: "BROWSER_WEB",
      audit_context: { auth_method: pending_mfa_auth_method.presence || "mfa" },
      bootstrap_actor: false,
      skip_login_cooldown: true,
      # The primary factor that gated MFA, not the step-up factor itself --
      # step-up attribution lives on last_step_up_method (adr/unified-enforcement.md,
      # Session revocation, rule 3). Captured before clear_pending_mfa! deletes
      # the session-backed value.
      established_authentication_method: pending_mfa_established_authentication_method,
    )
    advance_pending_sign_in_flow_after_primary!(cycle, user, result) if cycle

    if result[:status] == :session_limit_hard_reject
      { status: :session_limit_hard_reject, message: result[:message], http_status: result[:http_status] }
    elsif result[:session_management_required]
      { status: :restricted, redirect_path: session_management_path }
    elsif result[:status] == :success
      { status: :success, redirect_path: sign_in_sequence_redirect_path(pt: pt) }
    else
      result
    end
  end

  def session_management_path
    if respond_to?(:sign_app_sign_in_session_path, true)
      sign_app_sign_in_session_path
    elsif respond_to?(:sign_org_sign_in_session_path, true)
      sign_org_sign_in_session_path
    elsif respond_to?(:sign_com_sign_in_session_path, true)
      sign_com_sign_in_session_path
    else
      "/sign/in/session"
    end
  end

  # Default redirect destination after login for guest authentication mode.
  # Override in controllers to customize (e.g. to preserve ri parameter).
  def after_login_path
    default_after_login_path
  end

  def default_after_login_path
    if respond_to?(:auth_app_root_path, true)
      auth_app_root_path
    elsif respond_to?(:auth_org_root_path, true)
      auth_org_root_path
    else
      "/"
    end
  end

  def session_limit_gate_pt
    request&.fullpath.presence || request&.path.presence || "/"
  rescue StandardError
    "/"
  end

  def session_limit_gate_flow
    return "#{controller_path}.session" if respond_to?(:controller_path, true)

    "auth.#{resource_type}.session"
  end

  # Canonical entry point for establishing a signed-in session. Every
  # interactive sign-in, sign-up completion, and social callback must call
  # this (not log_in directly): it orchestrates the MFA decision and then
  # delegates to log_in, which performs the session-fixation reset_session.
  # Paired vocabulary with logout_current_session! for the privilege
  # transition points.
  def establish_signed_in_session!(resource, pt:, ri:, auth_method:, token_kind_id: "BROWSER_WEB",
                                   record_login_audit: true, audit_context: {}, bootstrap_actor: false,
                                   established_authentication_method: nil, authentication_context: nil)
    raise AlreadyAuthenticatedError if logged_in?

    auth_method = auth_method.to_s
    # `auth_method:` alone is sometimes ambiguous (e.g. "social" cannot express
    # google vs apple) -- callers with better information pass the resolved
    # value explicitly; otherwise it is derived from auth_method's known 1:1
    # mappings only. See ESTABLISHED_AUTHENTICATION_METHOD_MAP above.
    resolved_established_authentication_method =
      established_authentication_method.presence || established_authentication_method_for(auth_method)
    cycle = start_sign_in_flow_for!(resource, pt: pt)
    login_audit_context = { auth_method: auth_method }.merge(audit_context)
    if mfa_bypassed_for_auth_method?(auth_method) || !mfa_required_for?(resource)
      result = pending_sign_in_result_after_primary!(
        resource,
        pt: pt,
        record_login_audit: record_login_audit,
        token_kind_id: token_kind_id,
        audit_context: login_audit_context,
        bootstrap_actor: bootstrap_actor,
        established_authentication_method: resolved_established_authentication_method,
        authentication_context: authentication_context,
      )
      advance_pending_sign_in_flow_after_primary!(cycle, resource, result)
      return result
    end

    resolved_pt = resolve_mfa_pt(pt)
    cycle.advance_sign_in_to_mfa!
    sign_in_flow_locator_for(actor: resource).issue!(cycle)
    set_pending_mfa!(
      resource: resource, primary: auth_method, pt: resolved_pt, ri: ri,
      auth_method: auth_method,
      established_authentication_method: resolved_established_authentication_method,
    )

    {
      status: :mfa_required,
      redirect_path: mfa_entry_path(ri: ri),
      pt: resolved_pt,
    }
  end

  def pending_sign_in_result_after_primary!(resource, pt:, record_login_audit:, token_kind_id:,
                                            audit_context:, bootstrap_actor:, skip_login_cooldown: false,
                                            established_authentication_method: nil, authentication_context: nil)
    return { status: :login_forbidden } unless resource.login_allowed?

    session_limit_state = bootstrap_actor ? :within_limit : session_limit_state_for(resource)
    return session_limit_hard_reject_result(resource) if session_limit_state == :hard_reject

    if session_limit_state == :issue_restricted
      # This branch returns before log_in, so log_in's reset_session never runs -
      # yet store_pending_login_resource below writes the authenticated principal's
      # id into the session, and the session-management page treats that id as
      # authoritative (it lists and revokes the actor's sessions). That is a
      # privilege transition from anonymous to identified, so the session id must be
      # rotated here for the same reason log_in rotates it. OIDC RP state is
      # preserved across the reset exactly as log_in does at :359-362.
      oidc_rp_session_state = preserved_oidc_rp_session_state
      reset_session
      restore_oidc_rp_session_state!(oidc_rp_session_state)

      store_pending_login_resource(resource)
      issue_session_limit_gate!(
        pt: session_limit_gate_pt,
        flow: session_limit_gate_flow,
      )
      return { status: :success, session_management_required: true, redirect_path: session_management_path }
    end

    check_login_cooldown!(
      resource,
      bootstrap_actor: bootstrap_actor,
      skip_login_cooldown: skip_login_cooldown,
    )

    result = log_in(
      resource,
      record_login_audit: record_login_audit,
      token_kind_id: token_kind_id,
      require_totp_check: false,
      audit_context: audit_context,
      bootstrap_actor: bootstrap_actor,
      skip_login_cooldown: skip_login_cooldown,
      established_authentication_method: established_authentication_method,
      authentication_context: authentication_context,
    )
    return result unless result[:status] == :success

    result.merge(redirect_path: sign_in_sequence_redirect_path(pt: pt))
  end

  def check_login_cooldown!(resource, bootstrap_actor: false, skip_login_cooldown: false)
    cooldown = AuthenticationBase.login_cooldown
    return unless cooldown.positive?
    # Bootstrap handoffs (sign-up completion, OIDC authorization resume) issue a
    # token within seconds of the one minted moments earlier in the same flow.
    # That fresh token is not a rapid re-login attempt, so skip the cooldown gate
    # for the same reason the session-limit gate is skipped for bootstrap logins.
    # Without this, the sign-up -> OIDC resume handoff fails with 429.
    return if bootstrap_actor || skip_login_cooldown

    fk =
      if resource.is_a?(::Client)
        :user_id
      elsif resource.is_a?(::Visitor)
        :visitor_id
      else
        :staff_id
      end
    latest_at =
      token_record_connection_owner.connected_to(role: :reading) {
        token_class.where(fk => resource.id).order(created_at: :desc).pick(:created_at)
      }

    raise LoginCooldownError if latest_at && latest_at > cooldown.ago
  end

  def render_login_cooldown
    render plain: LOGIN_COOLDOWN_MESSAGE, status: :too_many_requests
  end

  # Determine concurrent-session handling state for the resource.
  def session_limit_state_for(resource)
    max_sessions = max_sessions_for_resource(resource)
    active_count = count_active_sessions(resource)

    return :within_limit if active_count < max_sessions
    return :hard_reject if restricted_session_exists?(resource)

    :issue_restricted
  end

  # Returns the maximum allowed concurrent sessions for a resource
  def max_sessions_for_resource(resource)
    if resource.is_a?(::Client)
      ::ClientToken::MAX_SESSIONS_PER_USER
    elsif resource.is_a?(::Operator)
      ::OperatorToken::MAX_SESSIONS_PER_STAFF
    elsif resource.is_a?(::Visitor)
      ::VisitorToken::MAX_SESSIONS_PER_VISITOR
    else
      2 # Default fallback
    end
  end

  # Count active (non-revoked, non-restricted) sessions for a resource
  def count_active_sessions(resource)
    token_record_connection_owner(token_class_for_resource(resource)).connected_to(role: :writing) do
      if resource.is_a?(::Client)
        ::ClientToken.active_status.where(user_id: resource.id).count
      elsif resource.is_a?(::Operator)
        ::OperatorToken.active_status.where(staff_id: resource.id).count
      elsif resource.is_a?(::Visitor)
        ::VisitorToken.active_status.where(visitor_id: resource.id).count
      else
        0
      end
    end
  end

  def restricted_session_exists?(resource)
    token_record_connection_owner(token_class_for_resource(resource)).connected_to(role: :writing) do
      scope = find_restricted_sessions_scope(resource)
      scope.present? && scope.exists?
    end
  end

  def find_restricted_sessions_scope(resource)
    if resource.is_a?(::Client)
      ::ClientToken.restricted_status.where(user_id: resource.id)
    elsif resource.is_a?(::Operator)
      ::OperatorToken.restricted_status.where(staff_id: resource.id)
    elsif resource.is_a?(::Visitor)
      ::VisitorToken.restricted_status.where(visitor_id: resource.id)
    end
  end

  def restricted_session_expires_at
    ttl = token_class.const_defined?(:RESTRICTED_TTL) ? token_class::RESTRICTED_TTL : RESTRICTED_SESSION_TTL
    Time.current + ttl
  end

  def scheduled_login_token_attributes(now: Time.current)
    return {} unless %w(operator visitor).include?(resource_type)

    ttl_class = (resource_type == "visitor") ? VisitorToken : OperatorToken
    discarded_at = now + ttl_class::LOGIN_SESSION_TTL
    {
      discarded_at: discarded_at,
      purged_at: discarded_at + ttl_class::DELETION_GRACE_PERIOD,
    }
  end

  # Store the pending login resource ID for session management
  def store_pending_login_resource(resource)
    if resource.is_a?(::Client)
      session[:pending_login_user_id] = resource.id
    elsif resource.is_a?(::Operator)
      session[:pending_login_staff_id] = resource.id
    elsif resource.is_a?(::Visitor)
      session[:pending_login_visitor_id] = resource.id
    end
  end

  def concurrent_session_limit_validation_error?(exception)
    record = exception.record
    return false unless record.is_a?(token_class)
    return false unless record.errors.respond_to?(:of_kind?)

    record.errors.size == 1 && record.errors.of_kind?(:base, :too_many)
  end

  # ======================================================================
  # 8) Session/MFA helper reads + response shapers
  # ======================================================================
  # Get the current session token record
  def current_session
    return @current_session if defined?(@current_session)
    return nil unless current_session_public_id

    find_logic = -> { find_token_record_by_session_identifier(current_session_public_id) }

    @current_session = token_record_connection_owner.connected_to(role: :writing, &find_logic)
  end

  def token_class_for_resource(resource)
    if resource.is_a?(::Client)
      ::ClientToken
    elsif resource.is_a?(::Operator)
      ::OperatorToken
    elsif resource.is_a?(::Visitor)
      ::VisitorToken
    else
      token_class
    end
  end

  def token_record_connection_owner(klass = token_class)
    connection_owner = klass
    connection_owner = connection_owner.superclass until connection_owner.connection_class? ||
        connection_owner == ApplicationRecord
    connection_owner
  end

  def find_token_record_by_session_identifier(session_identifier)
    device_bound_token = find_token_record_by_device_session_identifier(session_identifier)
    return device_bound_token if device_bound_token

    scope = token_class.includes(:device_session).where(public_id: session_identifier)
    if token_record_column?("oidc_sid") && uuid_identifier?(session_identifier)
      scope = scope.or(token_class.includes(:device_session).where(oidc_sid: session_identifier))
    end
    scope.first
  end

  # Check if the current session is restricted
  def current_session_restricted?
    actor_authn = Actor.authn if defined?(Actor)
    return actor_authn.restricted? if actor_authn&.signed_in?

    current_session&.restricted?
  end

  def current_session_restricted_for_authn
    return @current_session.restricted? if defined?(@current_session) && @current_session.present?
    return false if @current_session_public_id.blank?

    find_token_record_by_session_identifier(@current_session_public_id)&.restricted?
  end

  def actor_current_resource
    return unless defined?(Actor)

    actor_authn = Actor.authn
    return unless actor_authn.signed_in?
    return unless actor_authn.actor_type.to_s == resource_type.to_s

    actor = Actor.actor
    return if actor.equal?(Unauthenticated.instance)
    return if actor.blank?
    return unless actor.is_a?(resource_class)
    return unless actor_authn.actor_id.blank? || actor_authn.actor_id == actor.id

    actor
  end

  def dbsc_payload_for(token_record)
    return unless token_record

    {
      binding_method: dbsc_binding_method_name(token_record),
      status: dbsc_status_name(token_record),
      session_id: token_record.dbsc_session_id,
      registration_url: token_dbsc_path,
      verification_url: token_dbsc_path,
    }
  end

  def dbsc_cookie_value_for(token_record)
    return unless token_record&.binding_method_dbsc?

    token_record.dbsc_session_id.presence
  end

  def dbsc_cookie_expires_at_for(token_record, now: Time.current)
    return unless token_record&.binding_method_dbsc?

    [now + DBSC_COOKIE_TTL, token_record.discarded_at].compact.min
  end

  def issue_dbsc_registration_header_for(token_record)
    return unless token_record
    return if token_record.binding_method_dbsc?

    challenge = issue_dbsc_challenge_for!(token_record)
    return if challenge.blank?

    value = %((ES256 RS256);path="#{token_dbsc_path}";challenge="#{challenge}")
    response.set_header(
      AuthIoKeys::Headers::DBSC_REGISTRATION,
      value,
    )
    response.set_header(AuthIoKeys::Headers::SECURE_DBSC_REGISTRATION, value)
    Rails.logger.info(
      "[dbsc] registration header issued path=#{token_dbsc_path} challenge=#{challenge[0, 24]}",
    )
  end

  def attempt_transparent_refresh!(refresh_plain)
    return nil unless transparent_refresh_allowed?

    request.env[AuthIoKeys::Env::AUTH_REFRESHED_FLAG] = true

    if method(:refresh_access_token).arity == 1
      refresh_access_token(refresh_plain)
    else
      refresh_access_token(refresh_plain, allow_suspended: true)
    end
  end

  def transparent_refresh_allowed?
    return false unless respond_to?(:request, true) && request.present?
    return false unless request.get? || request.head?

    request.format.html?
  end

  def best_effort_refresh_side_effect
    yield
  rescue StandardError => e
    Rails.logger.warn(
      JitLogEvent.format(
        "auth.transparent_refresh.side_effect_failed",
        error_class: e.class.name,
        message: e.message,
      ),
    )
    nil
  end

  def issue_dbsc_challenge_for!(token_record)
    challenge = SecureRandom.urlsafe_base64(32)
    ActiveRecord::Base.connected_to(role: :writing) do
      token_record.class.find(token_record.id).update!(
        dbsc_challenge: challenge,
        dbsc_challenge_issued_at: Time.current,
      )
    end
    challenge
  end

  def token_dbsc_path
    raw =
      case resource_type
      when "client"
        dbsc_route_helper(:auth_app_edge_v0_token_dbsc_path, :sign_app_edge_v0_token_dbsc_path)
      when "operator"
        dbsc_route_helper(:auth_org_edge_v0_token_dbsc_path, :sign_org_edge_v0_token_dbsc_path)
      when "visitor"
        dbsc_route_helper(:auth_com_edge_v0_token_dbsc_path, :sign_com_edge_v0_token_dbsc_path)
      end
    # Canonicalize: the advertised DBSC path must not carry per-request context params.
    dbsc_canonical_url(raw)
  end

  def token_dbsc_url
    raw =
      case resource_type
      when "client"
        dbsc_route_helper(:auth_app_edge_v0_token_dbsc_url, :sign_app_edge_v0_token_dbsc_url)
      when "operator"
        dbsc_route_helper(:auth_org_edge_v0_token_dbsc_url, :sign_org_edge_v0_token_dbsc_url)
      when "visitor"
        dbsc_route_helper(:auth_com_edge_v0_token_dbsc_url, :sign_com_edge_v0_token_dbsc_url)
      end
    # Canonicalize: this URL is the DBSC proof audience and must match registration and
    # refresh byte-for-byte, so it cannot vary with request context (ri/lx/...).
    dbsc_canonical_url(raw)
  end

  def dbsc_route_helper(primary_helper, compatibility_helper)
    return public_send(primary_helper) if respond_to?(primary_helper, true)
    return public_send(compatibility_helper) if respond_to?(compatibility_helper, true)

    raise NoMethodError, "missing DBSC route helper for #{resource_type}"
  end

  def dbsc_binding_method_name(record)
    return "dbsc" if record.binding_method_dbsc?
    return "legacy" if record.binding_method_legacy?

    "nothing"
  end

  def dbsc_status_name(record)
    return "pending" if record.dbsc_status_pending?
    return "active" if record.dbsc_status_active?
    return "failed" if record.dbsc_status_failed?
    return "revoke" if record.dbsc_status_revoke?

    "nothing"
  end

  def token_expiry_column(klass)
    return :expired_at if klass.column_names.include?("expired_at")
    return :discarded_at if klass.column_names.include?("discarded_at")
    return :revoked_at if klass.column_names.include?("revoked_at")

    raise ArgumentError, "#{klass.name} does not have expired_at/revoked_at column"
  end

  def token_expired_or_revoked?(token_record, expiry_column)
    value = token_record.public_send(expiry_column)
    return true if value.nil?
    return false if value.respond_to?(:infinite?) && value.infinite?

    value <= Time.current
  end

  def refresh_cookie_expires_at_for(token_record)
    [token_record_expiry_at(token_record), token_record&.discarded_at].compact.min
  end

  def token_record_expiry_at(token_record)
    return unless token_record
    return token_record.revoked_at if token_record.respond_to?(:revoked_at)

    token_record.discarded_at if token_record.respond_to?(:discarded_at)
  end

  def expires_in_for(expires_at, now: Time.current)
    [(epoch_seconds(expires_at) - epoch_seconds(now)), 0].max
  end

  def epoch_seconds(value)
    return value.to_i if value.is_a?(Time) || value.is_a?(DateTime) || value.is_a?(ActiveSupport::TimeWithZone)
    return value.to_i if value.is_a?(ActiveSupport::Duration) || value.is_a?(Numeric)

    Integer(value.to_s, 10)
  rescue ArgumentError, TypeError
    0
  end

  def mfa_required_for?(resource)
    return false unless resource.is_a?(::Client) || resource.is_a?(::Operator) || resource.is_a?(::Visitor)
    return false unless resource.respond_to?(:mfa_level_required?) || resource.respond_to?(:mfa_level_enabled?)

    if resource.respond_to?(:mfa_level_required?)
      resource.mfa_level_required?
    else
      resource.mfa_level_enabled?
    end
  end

  # Auth methods that imply the user already presented local strong evidence
  # of presence, so a second TOTP factor would be redundant:
  #   - passkey: phishing-resistant authenticator possession
  # Social providers remain AAL1 here. Do not treat an external IdP assertion
  # as local MFA unless an explicit trust policy is introduced.
  # Email and telephone OTPs are *not* in this set -- OTP-only logins
  # still escalate to TOTP if the actor has enrolled an authenticator.
  # The "sign_up" fallback auth_method is intentionally absent too; in
  # practice it only fires for a freshly minted actor that has no MFA
  # enrolled yet, so the gate naturally passes via mfa_required_for?.
  def mfa_bypassed_for_auth_method?(auth_method)
    auth_method.to_s == "passkey"
  end

  def resolve_mfa_pt(raw_value)
    return nil if raw_value.blank?

    decoded = decode_base64_urlsafe(raw_value)
    candidate = decoded.presence || raw_value

    safe_internal_path(candidate)
  end

  def resolve_mfa_return_to(raw_value)
    resolve_mfa_pt(raw_value)
  end

  def decode_base64_urlsafe(value)
    Base64.urlsafe_decode64(value.to_s)
  rescue ArgumentError
    nil
  end

  def mfa_entry_path(ri: nil)
    if respond_to?(:sign_app_sign_in_challenge_path, true)
      sign_app_sign_in_challenge_path(ri: ri)
    elsif respond_to?(:sign_org_sign_in_challenge_path, true)
      sign_org_sign_in_challenge_path(ri: ri)
    else
      "/sign/in/challenge"
    end
  rescue StandardError
    "/sign/in/challenge"
  end

  def handle_auth_required_json(options)
    if @current_authentication_failure_reason == :withdrawal_required
      return render json: { error: "WITHDRAWAL_REQUIRED", error_code: "withdrawal_required" }, status: :forbidden
    end

    status = options[:status] || :unauthorized
    render json: { error: (options[:message] || "unauthorized") }, status: status
  end

  def handle_auth_required_html(options)
    if @current_authentication_failure_reason == :withdrawal_required
      return redirect_to(withdrawal_required_session_entry_path, allow_other_host: false)
    end

    path =
      if respond_to?(:sign_in_url_with_pt, true)
        store_authentication_return_target!(request.fullpath) unless respond_to?(
          :redirect_to_oidc_authorization_url,
          true,
        )
        pt = encoded_pt(request.fullpath) if respond_to?(:encoded_pt, true)
        sign_in_url_with_pt(pt)
      elsif main_app.respond_to?(:sign_in_path)
        main_app.sign_in_path
      else
        "/sign/in"
      end
    message = options[:message] || I18n.t("errors.messages.login_required")
    if path.match?(%r{\Ahttps?://}i) && respond_to?(:redirect_to_oidc_authorization_url, true)
      redirect_to_oidc_authorization_url(path, alert: message)
    elsif path.match?(%r{\Ahttps?://}i)
      redirect_to_jump_url(path, alert: message)
    else
      redirect_to(path, allow_other_host: false, alert: message)
    end

    convert_redirect_to_inertia_location!
  end

  def withdrawal_required_session_entry_path
    ri = params[AuthIoKeys::Params::RI]
    return new_base_app_identity_withdrawal_session_path(ri: ri) if controller_path.start_with?("base/app/")
    return new_base_com_identity_withdrawal_session_path(ri: ri) if controller_path.start_with?("base/com/")
    return new_base_app_identity_withdrawal_session_path(ri: ri) if controller_path.start_with?("auth/app/")
    return new_base_com_identity_withdrawal_session_path(ri: ri) if controller_path.start_with?("auth/com/")

    new_base_app_identity_withdrawal_session_path(ri: ri)
  end

  def handle_guest_only_json(options)
    status = options[:status] || :forbidden
    render json: { error: (options[:message] || "already_authenticated") }, status: status
  end

  def handle_guest_only_with_status_checks(options)
    if options[:no_redirect]
      status = options[:status] || :forbidden
      message = options[:message] || I18n.t("errors.messages.already_authenticated")
      return render plain: message, status: status
    end

    return handle_guest_only_html(options) if request.get? &&
      options[:request_format] != :json &&
      !request.format.json?

    if options[:status] == :unauthorized
      return render plain: (options[:message] || I18n.t("errors.messages.not_authorized")), status: :unauthorized
    end
    if options[:status] == :bad_request
      return render plain: (options[:message] || I18n.t("errors.messages.invalid_request")), status: :bad_request
    end

    handle_guest_only_html(options)
  end

  def handle_guest_only_html(options)
    path =
      if respond_to?(:after_login_path, true)
        after_login_path
      elsif main_app.respond_to?(:after_login_path)
        main_app.after_login_path
      else
        "/"
      end
    message = options[:message] || I18n.t("errors.messages.already_authenticated")
    redirect_to(path, allow_other_host: after_login_allows_other_host?, alert: message)
  end

  def after_login_allows_other_host?
    false
  end
end
