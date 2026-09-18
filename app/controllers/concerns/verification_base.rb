# typed: false
# frozen_string_literal: true

module VerificationBase
  extend ActiveSupport::Concern

  include CommonRedirect
  include ::RedirectsSignedTargetSupport
  include VerificationStepUpGuard

  STEP_UP_TTL = 15.minutes
  STEP_UP_REQUIRED_MESSAGE = "Step-up authentication required\nYour changes have not been saved"
  STEP_UP_PATH_TARGET_TOKEN_SALT = "path_target_token"
  STEP_UP_PATH_TARGET_TOKEN_PURPOSE = :path_target

  def verification_requirement
    @required_verification
  end

  def require_verification!(requirement)
    @required_verification = requirement.to_sym
  end

  def clear_verification_requirement!
    @required_verification = nil
  end

  def verification_required?
    verification_requirement.present? ||
      (respond_to?(:verification_required_action?, true) && verification_required_action?)
  end

  def verification_scope
    verification_requirement
  end

  def verification_required_aal
    StepUpRequirement::NO_AAL
  end

  def verification_satisfied?
    actor_token = current_actor_token
    return false unless actor_token

    scope = verification_scope
    if scope.present?
      return recorded_step_up_satisfied?(actor_token, scope: scope, required_aal: verification_required_aal)
    end

    verification_record_satisfied?(actor_token)
  end

  def verification_record_satisfied?(actor_token)
    raw_token = cookies[verification_model.cookie_name].to_s
    return false if raw_token.blank?

    digest = verification_model.digest_token(raw_token)
    verification = verification_model.active.find_by(
      verification_token_foreign_key => actor_token.id,
      :token_digest => digest,
    )

    return false unless verification

    begin
      verification.update!(last_used_at: Time.current)
    rescue ActiveRecord::ReadOnlyError
      nil
    end

    true
  end

  def recorded_step_up_satisfied?(token, scope:, required_aal: verification_required_aal)
    StepUpResolver.call(
      token: token,
      requirement: step_up_requirement(scope: scope, required_aal: required_aal),
    ).satisfied?
  end

  def step_up_satisfied?(scope:, required_aal: verification_required_aal)
    step_up = StepUpResolver.call(
      token: current_session_token,
      requirement: step_up_requirement(scope: scope, required_aal: required_aal),
    )
    Actor.install_context!(step_up: step_up) if defined?(Actor)
    step_up.satisfied?
  end

  def require_step_up!(scope:, required_aal: verification_required_aal)
    return false if reject_step_up_for_authentication_context!
    return false if step_up_session_revoked?
    return if step_up_satisfied?(scope: scope, required_aal: required_aal)

    log_step_up_required!(scope: scope, required_aal: required_aal)
    require_verification!(scope)
    return false unless enforce_step_up_prereqs!(scope_override: scope)

    flash[:alert] = I18n.t("auth.step_up.required")
    if request.get? || request.head?
      redirect_to(
        actor_verification_path(
          scope: scope,
          pt: encoded_relative_pt(request.fullpath),
          ri: params[:ri],
        ),
      )
      return false
    end

    if request.format.json?
      render json: { error: STEP_UP_REQUIRED_MESSAGE }, status: :unprocessable_content
    else
      render plain: STEP_UP_REQUIRED_MESSAGE, status: :unauthorized
    end
    false
  end

  def require_step_up_unless_bootstrap!(scope:, required_aal: verification_required_aal)
    return true if step_up_bootstrap_unconfigured?

    require_step_up!(scope: scope, required_aal: required_aal)
  end

  def step_up_requirement(scope:, required_aal: verification_required_aal, allowed_methods: step_up_strong_methods)
    StepUpRequirement.new(
      scope: scope,
      required_aal: required_aal,
      allowed_methods: allowed_methods,
      session_binding: current_session_token&.public_id,
      token_binding: current_session_token&.public_id,
      ttl: STEP_UP_TTL,
      purpose: :step_up,
      audience: step_up_audience,
      require_session_binding: true,
    )
  end

  private

  # An authentication context that is not eligible for Step-Up is rejected at
  # the ceremony entry, before any credential is requested. This is not "step-up
  # has not happened yet": no assertion can satisfy it, so offering the ceremony
  # would only produce a credential prompt that can never succeed. Changing
  # authentication mode requires signing out and signing in again.
  #
  # Rendered inline rather than through flash, and 403 rather than 401, because
  # the session is valid and the operation is unavailable to it.
  def reject_step_up_for_authentication_context!
    return false unless emergency_authentication_context?
    return true if performed?

    Rails.logger.info(
      JitLogEvent.format(
        "auth.step_up.authentication_context_ineligible",
        authentication_context: AuthenticationContextValue::EMERGENCY_KEY,
        session_public_id: current_session_token&.public_id,
      ),
    )

    message = I18n.t("auth.step_up.emergency_unavailable")
    if request.format.json?
      render json: { error: message }, status: :forbidden
    else
      render plain: message, status: :forbidden
    end
    true
  end

  def emergency_authentication_context?
    token = current_session_token
    token.respond_to?(:emergency_authentication_context?) && token.emergency_authentication_context?
  end

  # Check whether the underlying refresh token record has been revoked,
  # expired, or compromised.  If so, force-logout the session so that a
  # stale (but still JWT-valid) access token cannot pass step-up.
  def step_up_session_revoked?
    token = current_session_token
    return true if token.nil? # no record at all - dead
    return false if token.currently_usable? # alive

    # Session is dead in DB - tear it down.
    log_out if respond_to?(:log_out, true)

    render plain: I18n.t("auth.session_expired"), status: :unauthorized
    true
  end

  def enforce_verification_if_required
    return true if respond_to?(:logged_in?) && !logged_in?
    return true unless verification_required?
    return true if verification_satisfied?
    return false unless enforce_step_up_prereqs!(scope_override: verification_scope)

    handle_unverified_actor!
    false
  end

  def handle_unverified_actor!
    if request.get? || request.head?
      safe_redirect_to(
        verification_redirect_path(pt: encoded_step_up_pt),
        fallback: verification_redirect_fallback,
        status: :found,
      )
    elsif request.format.json?
      render json: { error: STEP_UP_REQUIRED_MESSAGE }, status: :unauthorized
    else
      render plain: STEP_UP_REQUIRED_MESSAGE, status: :unauthorized
    end
  end

  def enforce_step_up_prereqs!(scope_override: nil)
    return false if reject_step_up_for_authentication_context!
    return true if available_step_up_methods.present?

    if request.get? || request.head?
      return true if configured_step_up_methods.present? && verification_entry_request?

      destination =
        if step_up_bootstrap_unconfigured?
          verification_setup_redirect_path(pt: encoded_step_up_pt)
        else
          verification_redirect_path(pt: encoded_step_up_pt, scope_override: scope_override)
        end
      fallback =
        if step_up_bootstrap_unconfigured?
          verification_setup_redirect_fallback
        else
          verification_redirect_fallback
        end

      redirect_to_verification_destination(destination, fallback: fallback, status: :found)
    elsif request.format.json?
      render json: { error: I18n.t("auth.step_up.register_methods_required") }, status: :unprocessable_content
    else
      destination =
        if step_up_bootstrap_unconfigured?
          verification_setup_redirect_path(pt: encoded_step_up_pt)
        else
          verification_redirect_path(pt: encoded_step_up_pt, scope_override: scope_override)
        end
      fallback =
        if step_up_bootstrap_unconfigured?
          verification_setup_redirect_fallback
        else
          verification_redirect_fallback
        end

      redirect_to_verification_destination(
        destination,
        fallback: fallback,
        status: :see_other,
        alert: I18n.t("auth.step_up.register_methods_required"),
      )
    end
    false
  end

  def log_step_up_required!(scope:, required_aal:)
    step_up = defined?(Actor) ? Actor.step_up : nil

    Rails.logger.info(
      JitLogEvent.format(
        "auth.step_up.required",
        controller: self.class.name,
        action: action_name,
        method: request.request_method,
        format: request.format&.to_s,
        surface: (defined?(Actor) ? Actor.tld : nil),
        actor_type: (defined?(Actor) ? Actor.actor_type : nil),
        scope: scope,
        required_aal: required_aal,
        step_up_satisfied: step_up&.satisfied?,
        step_up_usable_token: step_up&.usable_token?,
        step_up_method: step_up&.method,
        step_up_scope: step_up&.scope,
        step_up_expires_at: step_up&.expires_at&.iso8601,
      ),
    )
  end

  def verification_entry_request?
    request.path == actor_verification_path
  end

  def encoded_step_up_pt
    safe_path = existing_step_up_pt_path.presence ||
      safe_internal_path(request.fullpath.to_s).presence ||
      "/"
    safe_path = unwrap_verification_pt_path(safe_path)
    issue_step_up_pt(safe_path)
  end

  def encoded_relative_pt(path)
    safe_path = safe_internal_path(path.to_s).presence || "/"
    issue_step_up_pt(safe_path)
  end

  def issue_step_up_pt(safe_path)
    surface = bootstrap_pt_surface
    session_nonce = bootstrap_pt_session_nonce
    claims = signed_target_claims(
      flow: bootstrap_pt_flow,
      surface: surface,
      session_nonce: session_nonce,
    )
    return nil if claims.blank?

    path = signed_target_internal_path(safe_path)
    return nil if path.blank?

    issue_signed_target_token(
      payload: claims.merge("pt" => path),
      purpose: STEP_UP_PATH_TARGET_TOKEN_PURPOSE,
      salt: STEP_UP_PATH_TARGET_TOKEN_SALT,
      expires_in: STEP_UP_TTL,
    )
  end

  def bootstrap_return_path(default_path)
    resolve_step_up_pt(request.parameters["pt"]) || default_path
  end

  def resolve_step_up_pt(encoded)
    encoded = encoded.to_s
    return nil if encoded.blank?

    signed = signed_pt_to_safe_path(encoded)
    signed.presence
  end

  def signed_pt_to_safe_path(token)
    surface = bootstrap_pt_surface
    return nil if surface.blank?

    payload = verified_signed_target_payload(
      token,
      purpose: STEP_UP_PATH_TARGET_TOKEN_PURPOSE,
      salt: STEP_UP_PATH_TARGET_TOKEN_SALT,
      expected_flow: bootstrap_pt_flow,
      expected_surface: surface,
      session_nonce: bootstrap_pt_session_nonce,
    )
    return nil if payload.blank?

    signed_target_internal_path(payload["pt"])
  end

  def bootstrap_pt_flow
    "step_up.bootstrap"
  end

  # Uses the stable session identifier (device_session.public_id when available) rather than
  # current_session_token.public_id, which changes on every access-token rotation and would
  # invalidate an in-flight step-up pt between the settings redirect and the verification page.
  def bootstrap_pt_session_nonce
    current_session_public_id.to_s
  end

  def bootstrap_pt_surface
    case self.class.name
    when /::App::/ then "app"
    when /::Com::/ then "com"
    when /::Org::/ then "org"
    end
  end

  def decode_pt_path(encoded)
    resolve_step_up_pt(encoded)
  end

  def setup_pt_path(encoded, root_path:)
    path = decode_pt_path(encoded)
    return nil if path.blank?

    uri = URI.parse(path)
    return root_path if uri.path.start_with?("/settings/") && uri.path != root_path

    path
  rescue URI::InvalidURIError
    nil
  end

  def existing_step_up_pt_path
    encoded = params[:pt].presence
    resolve_step_up_pt(encoded)
  end

  def unwrap_verification_pt_path(path)
    safe_path = safe_internal_path(path.to_s).presence || "/"

    5.times do
      uri = URI.parse(safe_path)
      break unless uri.path == actor_verification_path

      query = Rack::Utils.parse_nested_query(uri.query)
      encoded = query["pt"].presence
      break if encoded.blank?

      nested_path = resolve_step_up_pt(encoded)
      break if nested_path.blank? || nested_path == safe_path

      safe_path = nested_path
    end

    safe_path
  rescue URI::InvalidURIError
    safe_path
  end

  def current_session_token
    return @current_session_token if defined?(@current_session_token)
    return @current_session_token = current_session if respond_to?(:current_session, true) && current_session.present?
    return @current_session_token = nil if current_session_public_id.blank?

    @current_session_token = token_class.find_by(public_id: current_session_public_id)
  end

  def current_actor_token
    return @current_actor_token if defined?(@current_actor_token)
    if respond_to?(:current_session, true) && current_session&.currently_usable?
      return @current_actor_token = current_session
    end
    return @current_actor_token = nil if current_session_public_id.blank?

    token = token_class.find_by(public_id: current_session_public_id)
    return @current_actor_token = token if token&.currently_usable?

    @current_actor_token = nil
  end

  def step_up_strong_methods
    step_up_supported_methods
  end

  def verification_model
    actor_operator? ? OperatorVerification : ClientVerification
  end

  def verification_token_foreign_key
    actor_operator? ? :staff_token_id : :user_token_id
  end

  def actor_operator?
    false
  end

  def available_step_up_methods(actor = current_verification_actor)
    return @available_step_up_methods if actor.nil? && defined?(@available_step_up_methods)

    result = resolved_step_up_methods(actor).available
    @available_step_up_methods = result if actor.nil?
    result
  end

  def configured_step_up_methods(actor = current_verification_actor)
    return @configured_step_up_methods if actor.nil? && defined?(@configured_step_up_methods)

    result = resolved_step_up_methods(actor).configured
    @configured_step_up_methods = result if actor.nil?
    result
  end

  def resolved_step_up_methods(actor)
    ::StepUpMethodsResolver.call(
      actor: actor,
      ticket: current_step_up_ticket,
      supported_methods: step_up_permitted_methods,
    )
  end

  def step_up_bootstrap_unconfigured?(actor = current_verification_actor)
    return false unless actor

    refresh_actor_mfa_status(actor)
    configured_step_up_methods(actor).empty?
  end

  def step_up_bootstrap_active?(actor = current_verification_actor)
    return false unless actor

    return actor.mfa_status_active? if actor.respond_to?(:mfa_status_active?)

    configured_step_up_methods(actor).present?
  end

  def current_step_up_ticket
    token = current_session_token
    return token.step_up_session if token&.respond_to?(:step_up_session)

    nil
  end

  # The signed acme transaction is the authoritative operation policy.  A local
  # verification endpoint may offer only the intersection of that policy and the
  # fixed surface policy; no client parameter can expand either set.
  def step_up_permitted_methods
    supported = step_up_supported_methods
    return supported unless respond_to?(:current_step_up_session, true)

    scope = current_step_up_session&.scope
    return supported if scope.blank?

    transaction = current_step_up_ceremony_transaction_for_policy(scope)
    return supported unless transaction

    supported & transaction.allowed_methods_array.map(&:to_sym)
  end

  def current_step_up_ceremony_transaction_for_policy(scope)
    if respond_to?(:acme_step_up_completion_state?, true) && acme_step_up_completion_state?
      return current_step_up_ceremony_transaction!(scope: scope)
    end

    IdentityStepUpCeremonyReplayStore.for(step_up_ceremony_surface).latest_pending_for(
      actor_ref: step_up_ceremony_actor_ref,
      session_ref: actor_token.public_id,
      required_scope: scope,
    )
  end

  def step_up_supported_methods
    actor_operator? ? [:passkey] : %i(email_otp passkey totp)
  end

  def step_up_audience
    surface = bootstrap_pt_surface.to_s.presence || "unknown"
    "step_up:#{surface}"
  end

  def current_verification_actor
    return current_operator if actor_operator? && respond_to?(:current_operator)
    return current_visitor if respond_to?(:current_visitor)
    return current_client if respond_to?(:current_client)

    nil
  end

  def refresh_actor_mfa_status(actor)
    return unless actor.respond_to?(:refresh_mfa_status!)
    return if actor.destroyed?

    actor.refresh_mfa_status!
  end

  def verification_redirect_path(pt: nil, scope_override: nil)
    actor_verification_path(pt: pt, scope: scope_override || verification_scope, ri: params[:ri])
  end

  def verification_redirect_fallback
    actor_root_path(ri: params[:ri])
  end

  def verification_setup_redirect_path(pt: nil)
    actor_verification_setup_path(pt: pt, ri: params[:ri])
  end

  def verification_setup_redirect_fallback
    actor_root_path(ri: params[:ri])
  end

  def redirect_to_verification_destination(destination, fallback:, **redirect_options)
    if destination.to_s.start_with?("/")
      safe_redirect_to(destination, fallback: fallback, **redirect_options)
    else
      redirect_to(
        destination,
        allow_other_host: cross_host_redirect_allowed?,
        **redirect_options,
      )
    end
  end

  def actor_verification_path(**args)
    actor_operator? ? auth_org_verification_path(**args) : auth_app_verification_path(**args)
  end

  def actor_verification_setup_path(**args)
    actor_operator? ? new_auth_org_verification_setup_path(**args) : new_auth_app_verification_setup_path(**args)
  end

  def actor_root_path(**args)
    actor_operator? ? auth_org_root_path(**args) : auth_app_root_path(**args)
  end
end
