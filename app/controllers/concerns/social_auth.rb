# typed: false
# frozen_string_literal: true

# Controller concern for handling OAuth social authentication flow.
# Provides intent/state management and callback processing.
#
# Intent Flow:
# 1. User submits GET /social/:provider/sign/in or /social/:provider/sign/up
# 2. Controller calls prepare_social_auth_intent!("link")
# 3. User is redirected to OmniAuth provider
# 4. Provider redirects back to callback
# 5. Controller calls validate_social_auth_state! and process_social_auth_callback
#
# Security:
# - State parameter prevents CSRF attacks (applied to ALL providers including Apple)
# - Intent is stored in session, not passed via URL to prevent tampering
# - State expires after 5 minutes
module SocialAuth
  extend ActiveSupport::Concern

  SOCIAL_INTENT_SESSION_KEY = :social_auth_intent
  SOCIAL_USER_ID_SESSION_KEY = :social_auth_user_id
  SOCIAL_STARTED_AT_SESSION_KEY = :social_auth_started_at
  SOCIAL_FLOW_ID_SESSION_KEY = :social_auth_flow_id
  SOCIAL_PROVIDER_SESSION_KEY = :social_auth_provider
  SOCIAL_PT_SESSION_KEY = :social_auth_pt
  SOCIAL_ENTRY_SESSION_KEY = :social_auth_entry
  SOCIAL_RI_SESSION_KEY = :social_auth_ri
  # Stores the social ceremony transaction id, not the JWT grant. Keeping the
  # JWT in the cookie-backed session can exceed the 4KB cookie limit.
  SOCIAL_CEREMONY_GRANT_SESSION_KEY = :social_ceremony_grant
  STATE_TTL = 5.minutes
  STEP_UP_TTL = 10.minutes
  SOCIAL_LINK_SCOPE = "social_link"

  VALID_INTENTS = %w(login link step_up).freeze

  private

  # Prepare social auth intent before redirecting to OmniAuth provider.
  # Stores intent context in session (no custom state; OmniAuth handles OAuth state).
  #
  # @param intent [String] One of: "login", "link"
  # @return [void]
  def prepare_social_auth_intent!(intent, provider: nil, pt: nil, entry: nil, ri: nil)
    intent = intent.to_s
    raise SocialAuth::UnauthorizedError.new("errors.social_auth.invalid_intent") unless VALID_INTENTS.include?(intent)

    validate_social_auth_login_requirement!(intent)
    if intent == "link"
      @social_auth_intent_snapshot = intent
      @social_auth_provider_snapshot = provider
      authorize_social_auth_link!(social_auth_authorization_resource)
      require_recent_step_up!
    end

    store_social_auth_intent_context(intent, provider: provider, pt: pt, entry: entry, ri: ri)
    store_oauth_callback_state(provider)
    store_social_auth_user_context(intent)

    session[SocialCallbackGuard::SOCIAL_STATE_SESSION_KEY]
  end

  def validate_social_auth_login_requirement!(intent)
    return unless intent == "link" && !logged_in?

    raise SocialAuth::UnauthorizedError.new("errors.social_auth.not_logged_in")
  end

  def store_social_auth_intent_context(intent, provider:, pt:, entry:, ri:)
    _ = pt
    if intent == "login"
      session.delete(SOCIAL_INTENT_SESSION_KEY)
      session.delete(SOCIAL_STARTED_AT_SESSION_KEY)
      session.delete(SOCIAL_FLOW_ID_SESSION_KEY)
      session.delete(SOCIAL_PROVIDER_SESSION_KEY)
    else
      session[SOCIAL_INTENT_SESSION_KEY] = intent
      session[SOCIAL_STARTED_AT_SESSION_KEY] = Time.current.to_i
      session[SOCIAL_FLOW_ID_SESSION_KEY] = SecureRandom.hex(16)
      session[SOCIAL_PROVIDER_SESSION_KEY] = provider
    end
    session[:social_auth_nonce] = SecureRandom.urlsafe_base64(32) if provider.to_s == "apple"
    session[SOCIAL_ENTRY_SESSION_KEY] = entry if entry.present?
    session[SOCIAL_RI_SESSION_KEY] = ri if ri.present?
    session.delete(SOCIAL_PT_SESSION_KEY)
  end

  def store_oauth_callback_state(provider)
    state = SecureRandom.hex(16)
    session[SocialCallbackGuard::SOCIAL_STATE_SESSION_KEY] = state
    session[SocialCallbackGuard::SOCIAL_STATE_STARTED_AT_SESSION_KEY] = Time.current.to_i
    session.delete(SocialCallbackGuard::SOCIAL_STATE_USED_AT_SESSION_KEY)
    session[SocialCallbackGuard::SOCIAL_STATE_PROVIDER_SESSION_KEY] = provider
    SocialAuthCallbackStateStore.issue!(
      state: state,
      provider: provider,
      intent: session[SOCIAL_INTENT_SESSION_KEY],
    )
  end

  def store_social_auth_user_context(intent)
    if intent == "link"
      session[SOCIAL_USER_ID_SESSION_KEY] = current_resource&.id
    else
      session.delete(SOCIAL_USER_ID_SESSION_KEY)
    end
  end

  # Validate social auth context from session for link intent.
  # OAuth state validation is handled by OmniAuth.
  #
  # @raise [SocialAuth::UnauthorizedError] if context is missing or expired
  def validate_social_auth_state!
    intent = current_social_auth_intent
    return if intent == "login"

    snapshot_social_auth_context(intent)

    provider = omniauth_provider
    validate_intent_presence!(intent, provider)
    validate_intent_ttl!(provider)
    validate_user_consistency!(intent)
  end

  def validate_intent_presence!(intent, provider)
    return if intent == "link" && session[SOCIAL_FLOW_ID_SESSION_KEY].present?

    Rails.logger.info(JitLogEvent.format("social_auth.state_missing", provider: provider))
    raise SocialAuth::UnauthorizedError.new("errors.social_auth.state_missing")
  end

  def extract_callback_state
    request.parameters["state"].to_s.presence
  end

  def current_social_auth_intent
    session[SOCIAL_INTENT_SESSION_KEY] || "login"
  end

  def current_social_auth_entry
    session[SOCIAL_ENTRY_SESSION_KEY].presence
  end

  def current_social_auth_ri
    session[SOCIAL_RI_SESSION_KEY].presence
  end

  def clear_social_auth_intent!
    session.delete(SOCIAL_INTENT_SESSION_KEY)
    session.delete(SOCIAL_USER_ID_SESSION_KEY)
    session.delete(SOCIAL_STARTED_AT_SESSION_KEY)
    session.delete(SOCIAL_FLOW_ID_SESSION_KEY)
    session.delete(SOCIAL_PROVIDER_SESSION_KEY)
    session.delete(SOCIAL_PT_SESSION_KEY)
    session.delete(SOCIAL_ENTRY_SESSION_KEY)
    session.delete(SOCIAL_RI_SESSION_KEY)
    session.delete(SOCIAL_CEREMONY_GRANT_SESSION_KEY)
    session.delete(:social_auth_nonce)
    session.delete(SocialCallbackGuard::SOCIAL_STATE_SESSION_KEY)
    session.delete(SocialCallbackGuard::SOCIAL_STATE_STARTED_AT_SESSION_KEY)
    session.delete(SocialCallbackGuard::SOCIAL_STATE_USED_AT_SESSION_KEY)
    session.delete(SocialCallbackGuard::SOCIAL_STATE_PROVIDER_SESSION_KEY)
    @social_auth_intent_snapshot = nil
    @social_auth_provider_snapshot = nil
    @social_auth_user = nil
  end

  def require_recent_step_up!(ttl: STEP_UP_TTL)
    return unless current_resource

    step_up = recent_social_auth_step_up(ttl: ttl)
    return if step_up.satisfied?

    # Emit the binding breakdown (booleans + the required scope only -- never the
    # token value or other PII) so operators can tell *why* the step-up was
    # rejected: expired vs. wrong session/token vs. purpose/audience mismatch.
    # A scope/aal/method mismatch shows up as usable_token=true with every
    # *_bound=true yet satisfied=false.
    Rails.logger.info(
      JitLogEvent.format(
        "social_auth.step_up_required",
        user_id: current_resource.id,
        last_step_up_at: step_up.satisfied_at&.iso8601,
        required_within: Integer(ttl.to_s, 10),
        required_scope: SOCIAL_LINK_SCOPE,
        usable_token: step_up.usable_token?,
        session_bound: step_up.session_bound,
        token_bound: step_up.token_bound,
        purpose_bound: step_up.purpose_bound,
        audience_bound: step_up.audience_bound,
      ),
    )
    raise SocialAuth::StepUpRequiredError.new("errors.social_auth.step_up_required")
  end

  def recent_social_auth_step_up(ttl:)
    token = social_auth_current_session_token
    StepUpResolver.call(
      token: token,
      requirement: social_auth_step_up_requirement(token, ttl: ttl),
    )
  end

  def social_auth_step_up_requirement(token, ttl:)
    StepUpRequirement.new(
      scope: SOCIAL_LINK_SCOPE,
      step_up_required: true,
      allowed_methods: step_up_supported_methods,
      phishing_resistant_required: false,
      user_verification_required: false,
      full_reauthentication_required: false,
      session_binding: token&.public_id,
      token_binding: token&.public_id,
      ttl: ttl,
      purpose: :step_up,
      audience: social_auth_step_up_audience,
      require_session_binding: true,
      actor_ref: current_resource&.public_id,
      resource_ref: nil,
      tenant_ref: nil,
    )
  end

  def social_auth_current_session_token
    return current_session_token if respond_to?(:current_session_token, true)
    return nil unless respond_to?(:current_session_public_id, true) && respond_to?(:token_class, true)

    public_id = current_session_public_id
    return nil if public_id.blank?

    token_class.find_by(public_id: public_id)
  end

  def social_auth_step_up_audience
    step_up_audience if respond_to?(:step_up_audience, true)
  end

  def process_social_auth_callback(callback_result)
    unless callback_result.is_a?(ExternalAuthentication::CallbackResult) && callback_result.verified?
      raise SocialAuth::ProviderError.new("errors.social_auth.provider_error")
    end

    @external_authentication_callback_result = callback_result

    intent = current_social_auth_intent
    entry = current_social_auth_entry
    flow_id = session[SOCIAL_FLOW_ID_SESSION_KEY]
    log_social_auth_callback_received(intent, flow_id)
    authorize_social_auth_link!(social_auth_user) if intent == "link"

    result = resolve_social_auth_callback_result(callback_result, intent)
    result = result.with(entry: entry) if result && entry.present?

    clear_social_auth_intent!
    log_social_auth_callback_completed(intent, flow_id)
    result
  end

  def reject_grantless_established_social_login!(principal, intent)
    return unless intent.to_s == "login"
    return if social_ceremony_grant_token.present?
    return unless acme_social_login_completion_supported?(principal)

    raise SocialAuth::UnauthorizedError.new("errors.social_auth.invalid_intent")
  end

  def process_social_ceremony_login_callback(callback_result)
    grant = social_ceremony_grant
    result_token = IdentitySocialCeremonyResultIssuer.issue!(
      grant_token: social_ceremony_grant_token,
      callback_result: callback_result,
      surface: "app",
      actor_ref: grant["actor_ref"],
      session_ref: grant["session_ref"],
      operation: "login",
      challenge_id: extract_callback_state,
    )
    result_reference = Valkey::AuthState::SocialCeremonyResultStore.new.issue!(
      token: result_token, expires_at: grant.expires_at,
    )
    clear_social_auth_intent!
    redirect_to(
      base_app_social_authentication_completion_url(
        id: callback_result.principal.provider, result_ref: result_reference, ri: params[:ri],
        host: base_authority_host, protocol: "https",
      ), status: :see_other,
         allow_other_host: true,
    )
    nil
  end

  # Whether a callback identity is an *established / completed* account that must
  # complete login through acme rather than the bounded-legacy sign-side signup
  # path.
  #
  # Bounded legacy: "completed account" is currently approximated by
  # birthdate-present, because birthdate is the final required checkpoint of the
  # client sign-up flow (an account that has it has finished signup). This is a
  # heuristic, not a status check; it is intentionally conservative so that only
  # accounts that have clearly finished signup are routed to (and, when grantless,
  # rejected by) the acme-owned established-login path. Unknown / incomplete
  # accounts remain on the compatibility signup path. If account completeness
  # gains a first-class status predicate, replace this with that predicate.
  def acme_social_login_completion_supported?(principal)
    identity = social_auth_identity_for_callback(principal)

    identity&.user&.birthdate.present?
  end

  def social_auth_identity_for_callback(principal)
    return nil unless principal.is_a?(ExternalAuthentication::VerifiedPrincipal)

    ExternalAuthentication::IdentityRepositoryFactory.current.build(principal.provider)
      .find_by_subject(principal.subject, lock: false)
  rescue SocialAuth::BaseError, ArgumentError
    nil
  end

  def omniauth_auth_hash
    request.env["omniauth.auth"]
  end

  def omniauth_provider
    omniauth_auth_hash&.provider
  end

  def omniauth_authorize_path(provider, state: nil)
    request_provider =
      case SocialIdentifiable.normalize_provider(provider)
      when "google" then "google"
      when "apple" then "apple"
      else provider.to_s
      end

    return "/social/#{request_provider}" if state.blank?

    "/social/#{request_provider}?state=#{CGI.escape(state)}"
  end

  def social_auth_user
    return current_resource if current_resource.present?

    intent = current_social_auth_intent
    return nil unless intent == "link"

    user_id = session[SOCIAL_USER_ID_SESSION_KEY].presence
    return nil if user_id.blank?

    @social_auth_user ||=
      begin
        klass = respond_to?(:resource_class, true) ? resource_class : Client
        klass.find_by(id: user_id)
      end
  end

  def authorize_social_auth_link!(resource)
    raise SocialAuth::UnauthorizedError.new("errors.social_auth.not_logged_in") unless resource
    return if social_auth_link_allowed?(resource)

    raise SocialAuth::UnauthorizedError.new("errors.social_auth.not_logged_in")
  end

  def store_social_ceremony_grant!(token)
    grant = IdentitySocialCeremonyGrant.decode(
      token.to_s,
      issuer_id: IdentitySocialCeremonyContract.acme_issuer_id("app"),
    )
    unless %w(link login signup).include?(grant["operation"].to_s)
      raise SocialAuth::UnauthorizedError.new("errors.social_auth.invalid_intent")
    end

    if grant["operation"].to_s == "link"
      raise SocialAuth::UnauthorizedError.new("errors.social_auth.user_changed") unless grant["actor_ref"].to_s ==
        current_resource&.public_id.to_s
      raise SocialAuth::UnauthorizedError.new("errors.social_auth.user_changed") unless grant["session_ref"].to_s ==
        current_session_public_id.to_s
    end

    session[SOCIAL_CEREMONY_GRANT_SESSION_KEY] = grant["transaction_id"].to_s
  rescue IdentitySocialCeremonyContract::Error
    raise SocialAuth::UnauthorizedError.new("errors.social_auth.invalid_intent")
  end

  def social_ceremony_grant_token
    raw_value = session[SOCIAL_CEREMONY_GRANT_SESSION_KEY].presence
    return nil if raw_value.blank?

    return raw_value if raw_value.include?(".")

    transaction = IdentitySocialCeremonyReplayStore.for("app").find_transaction!(raw_value)
    IdentitySocialCeremonyGrant.issue(
      transaction.grant_claims,
      issuer_id: IdentitySocialCeremonyContract.acme_issuer_id("app"),
    )
  rescue IdentitySocialCeremonyContract::Error
    nil
  end

  def social_ceremony_grant
    @social_ceremony_grant ||= IdentitySocialCeremonyGrant.decode(
      social_ceremony_grant_token.to_s,
      issuer_id: IdentitySocialCeremonyContract.acme_issuer_id("app"),
    )
  end

  def social_ceremony_grant_operation
    social_ceremony_grant["operation"].to_s
  rescue IdentitySocialCeremonyContract::Error
    nil
  end

  def social_auth_authorization_resource
    return current_resource if respond_to?(:current_resource, true) && current_resource.present?
    return current_client if respond_to?(:current_client, true) && current_client.present?
    return current_operator if respond_to?(:current_operator, true) && current_operator.present?
    return current_visitor if respond_to?(:current_visitor, true) && current_visitor.present?

    nil
  end

  def social_auth_link_allowed?(resource)
    return allowed_to?(:update?, resource, context: { user: resource }) if respond_to?(:allowed_to?, true)

    policy_class =
      case resource
      when Client
        ClientPolicy
      when Operator
        OperatorPolicy
      end
    return false unless policy_class

    policy_class.new(resource, user: resource).apply(:update?)
  end

  def social_auth_request_method
    request.request_method if request.respond_to?(:request_method)
  rescue StandardError
    nil
  end

  def social_auth_request_path
    return request.path if request.respond_to?(:path)
    return request.fullpath if request.respond_to?(:fullpath)

    nil
  rescue StandardError
    nil
  end

  def handle_social_auth_error(error)
    intent = @social_auth_intent_snapshot || current_social_auth_intent
    provider = @social_auth_provider_snapshot || omniauth_provider
    reason = classify_social_auth_error_reason(error)

    log_social_auth_error_details(error, intent, provider, reason)

    respond_to do |format|
      format.html do
        flash[:alert] = error.message
        clear_social_auth_intent!
        redirect_to(social_auth_failure_redirect_path_for_intent(intent: intent, provider: provider))
      end
      format.json do
        clear_social_auth_intent!
        render json: { error: error.message }, status: error.status_code
      end
    end
  end

  def handle_record_not_unique(error)
    intent = @social_auth_intent_snapshot || current_social_auth_intent
    provider = @social_auth_provider_snapshot || omniauth_provider

    Rails.logger.info(
      JitLogEvent.format(
        "social_auth.record_not_unique",
        error_message: error.message,
      ),
    )

    respond_to do |format|
      format.html do
        flash[:alert] = I18n.t("errors.social_auth.identity_conflict")
        clear_social_auth_intent!
        redirect_to(social_auth_failure_redirect_path_for_intent(intent: intent, provider: provider))
      end
      format.json do
        clear_social_auth_intent!
        render json: { error: I18n.t("errors.social_auth.identity_conflict") }, status: :conflict
      end
    end
  end

  # Override this method to customize the failure redirect path
  def social_auth_failure_redirect_path
    respond_to?(:auth_app_sign_in_path) ? auth_app_sign_in_path : "/"
  end

  # Override this method to customize the success redirect path
  def social_auth_success_redirect_path
    respond_to?(:auth_app_root_path) ? auth_app_root_path : "/"
  end

  def validate_intent_ttl!(provider)
    started_at = session[SOCIAL_STARTED_AT_SESSION_KEY]
    return if started_at.blank?
    return if Time.current <= Time.zone.at(Integer(started_at.to_s, 10)) + STATE_TTL

    Rails.logger.info(
      JitLogEvent.format(
        "social_auth.intent_expired",
        provider: provider,
        started_at: started_at,
        surface: social_auth_observability_surface,
        region: params[:ri],
        flow_id: session[SOCIAL_FLOW_ID_SESSION_KEY],
        request_id: social_auth_request_id,
      ),
    )
    raise SocialAuth::UnauthorizedError.new("errors.social_auth.state_expired")
  end

  def validate_user_consistency!(intent)
    return unless intent == "link"

    intent_user_id = session[SOCIAL_USER_ID_SESSION_KEY].to_s
    current_id = social_auth_user&.id&.to_s

    return unless intent_user_id.blank? || current_id.blank? || intent_user_id != current_id

    raise SocialAuth::UnauthorizedError.new("errors.social_auth.user_changed")
  end

  def snapshot_social_auth_context(intent)
    @social_auth_intent_snapshot ||= intent
    @social_auth_provider_snapshot ||= omniauth_provider
  end

  def social_auth_observability_surface
    return sign_signup_observability_surface if respond_to?(:sign_signup_observability_surface, true)

    case self.class.name
    when /\ASign::Com::/ then :com
    when /\ASign::Org::/ then :org
    else :app
    end
  end

  def social_auth_failure_redirect_path_for_intent(intent:, provider:)
    return social_auth_failure_redirect_path unless intent == "link"

    provider_from_path = request.path.to_s.split("/social/").last&.split("/")&.first
    provider = provider.presence || session[SOCIAL_PROVIDER_SESSION_KEY] || params[:provider] || provider_from_path

    if provider.to_s == "apple"
      return auth_app_settings_apple_path if respond_to?(:auth_app_settings_apple_path, true)
      if Rails.application.routes.url_helpers.respond_to?(:auth_app_settings_apple_path)
        return Rails.application.routes.url_helpers.auth_app_settings_apple_path
      end
    end

    return auth_app_settings_path if respond_to?(:auth_app_settings_path, true)
    if Rails.application.routes.url_helpers.respond_to?(:auth_app_settings_path)
      return Rails.application.routes.url_helpers.auth_app_settings_path
    end

    social_auth_failure_redirect_path
  end

  def social_auth_request_id
    request.respond_to?(:request_id) ? request.request_id : nil
  end

  def log_social_auth_callback_received(intent, flow_id)
    Rails.logger.info(
      JitLogEvent.format(
        "social_auth.callback.received",
        provider: omniauth_provider,
        surface: social_auth_observability_surface,
        region: params[:ri],
        flow_id: flow_id,
        request_id: social_auth_request_id,
        intent: intent,
        callback_path: social_auth_request_path,
        state_present: extract_callback_state.present?,
        candidate_present: social_ceremony_grant_token.present?,
        session_present: session.present?,
      ),
    )
  end

  def log_social_auth_callback_completed(intent, flow_id)
    Rails.logger.info(
      JitLogEvent.format(
        "social_auth.callback.completed",
        provider: omniauth_provider,
        surface: social_auth_observability_surface,
        region: params[:ri],
        flow_id: flow_id,
        request_id: social_auth_request_id,
        intent: intent,
      ),
    )
  end

  def resolve_social_auth_callback_result(callback_result, intent)
    principal = callback_result.principal
    if social_ceremony_grant_token.present? && social_ceremony_grant_operation == "login" &&
        acme_social_login_completion_supported?(principal)
      process_social_ceremony_login_callback(callback_result)
    else
      reject_grantless_established_social_login!(principal, intent)
      resolve_external_authentication_use_case(callback_result, intent)
    end
  end

  def resolve_external_authentication_use_case(callback_result, intent)
    case intent.to_s
    when "login"
      login_result = ExternalAuthenticationLoginUseCase.call(
        principal: callback_result.principal,
        credential_candidate: callback_result.credential_candidate,
        sign_up_entry: true,
      )
      return ExternalAuthentication::CallbackOutcome.new(
        status: :signup_required,
        user: nil,
        identity: nil,
        existing_account: false,
      ) if login_result.signup_required?

      ExternalAuthentication::CallbackOutcome.new(
        status: :authenticated,
        user: login_result.user,
        identity: login_result.identity,
        existing_account: login_result.existing_account,
      )
    when "link"
      link_result = ExternalAuthenticationLinkUseCase.call(
        principal: callback_result.principal,
        credential_candidate: callback_result.credential_candidate,
        user: social_auth_user,
      )
      ExternalAuthentication::CallbackOutcome.new(
        status: :link_completed,
        user: link_result.user,
        identity: link_result.identity,
        existing_account: nil,
      )
    else
      raise SocialAuth::UnauthorizedError.new("errors.social_auth.invalid_intent")
    end
  end

  def classify_social_auth_error_reason(error)
    case error.respond_to?(:i18n_key) ? error.i18n_key.to_s : nil
    when "errors.social_auth.invalid_intent", "errors.social_auth.unauthorized" then "intent_invalid"
    when "errors.social_auth.state_expired" then "state_expired"
    when "errors.social_auth.state_missing" then "state_invalid"
    when "errors.social_auth.provider_error" then "provider_failed"
    else "unexpected_error"
    end
  end

  def log_social_auth_error_details(error, intent, provider, reason)
    Rails.logger.info(
      JitLogEvent.format(
        "social_auth.error_context",
        intent: intent,
        provider: provider,
        request_method: social_auth_request_method,
        request_path: social_auth_request_path,
      ),
    )

    Rails.logger.info(
      JitLogEvent.format(
        "social_auth.error",
        error_class: error.class.name,
        error_message: error.message,
        status_code: error.status_code,
      ),
    )

    log_social_auth_error_reason(reason, provider, intent)
  end

  def log_social_auth_error_reason(reason, provider, intent)
    event_name =
      case reason
      when "intent_invalid" then "social_auth.intent.invalid"
      when "state_expired" then "social_auth.state.expired"
      when "state_invalid" then "social_auth.state.invalid"
      when "provider_failed" then "social_auth.provider.failed"
      else "social_auth.candidate.not_found"
      end

    Rails.logger.info(
      JitLogEvent.format(
        event_name,
        provider: provider,
        surface: social_auth_observability_surface,
        region: params[:ri],
        flow_id: session[SOCIAL_FLOW_ID_SESSION_KEY],
        request_id: social_auth_request_id,
        intent: intent,
        reason: reason,
      ),
    )
  end
end
