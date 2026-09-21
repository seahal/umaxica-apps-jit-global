# typed: false
# frozen_string_literal: true

# Manages session limits for App users.
#
# When a user exceeds their maximum concurrent sessions (2 active) during login,
# they are logged in with a "restricted" session that only allows session management.
# This controller handles:
#   - show: Display active and restricted sessions
#   - update: Promote restricted session to active (after revoking an active session)
#   - destroy: Cancel the restricted session (logout) or revoke a specific session
#
# Routes:
#   GET    /in/session  -> #show
#   PATCH  /in/session  -> #update
#   DELETE /in/session  -> #destroy
#
# The restricted session approach avoids blocking login while ensuring users
# can manage their sessions. Invariant: max 1 restricted session per user.
class Auth::App::Sign::In::SessionsController < ::Auth::App::ApplicationController
  include SessionLimitGate
  include ::SurfaceInertiaPage

  AUTHENTICATION_MODE = :deny_all

  # `update` and `destroy` also answer with the session management page, so the component cannot be
  # derived from the action name.
  SESSION_PAGE_COMPONENT = "auth/app/sign/in/sessions/show"

  # This controller handles session management for both authenticated users
  # and users who are in the process of logging in (with a pending gate).
  declare_authentication_mode! :open

  # For show/update/destroy, user must be logged in (even if restricted)
  before_action :require_authentication_or_gate
  prepend_before_action :render_expired_restricted_session_locked, only: :show
  ensure_fqdn_gate_first!

  # Display active and restricted sessions for the user
  def show
    load_session_data
    render inertia: SESSION_PAGE_COMPONENT, props: session_page_props
  end

  # Revoke selected sessions and optionally promote restricted to active
  def update
    @current_client = resolve_current_client
    return redirect_to_login unless @current_client

    ref = params[:ref]

    if ref.present?
      # Revoke a specific session by signed reference
      revoke_session_by_ref(@current_client, ref)
    else
      # Revoke selected sessions by signed references
      refs = Array(params[:revoke_refs]).compact_blank
      if refs.empty?
        @session_alert = I18n.t("sign.app.in.session.no_sessions_selected")
        load_session_data
        return render inertia: SESSION_PAGE_COMPONENT,
                      props: session_page_props,
                      status: :unprocessable_content
      end

      revoke_sessions_by_refs(@current_client, refs)
    end

    # Check if we can promote restricted session to active
    if (pending_session_limit_cycle? || current_session_restricted?) && can_promote_session?(@current_client)
      if pending_oidc_session_limit_cycle?
        resume_url = promote_current_session_limit_cycle_for_oidc_handoff!(@current_client)
        if resume_url.present?
          consume_session_limit_gate!
          session.delete(:pending_login_user_id)
          return redirect_to(resume_url, allow_other_host: false)
        end
      end

      if pending_session_limit_cycle? && promote_current_session_limit_cycle!(@current_client)
        consume_session_limit_gate!
        return redirect_to_sign_in_sequence!(
          pt: retrieve_pt.presence || session_limit_pt,
        )
      end

      promote_current_session!
      consume_session_limit_gate!
      session.delete(:pending_login_user_id)
      return redirect_to_return_path
    end

    # Still restricted, stay on session management
    @session_notice = I18n.t("sign.app.in.session.sessions_revoked")
    load_session_data
    render inertia: SESSION_PAGE_COMPONENT, props: session_page_props
  end

  # Cancel the restricted session (logout) or revoke a specific session
  def destroy
    @current_client = resolve_current_client
    return redirect_to_login unless @current_client

    ref = params[:ref]

    if ref.present?
      # Revoke a specific session by signed reference
      revoke_session_by_ref(@current_client, ref)
      load_session_data
      render inertia: SESSION_PAGE_COMPONENT, props: session_page_props
    else
      current_db_sign_in_flow_for_sequence&.fail_sign_in! if pending_session_limit_cycle?
      consume_session_limit_gate!
      session.delete(:pending_login_user_id)

      if current_session&.restricted?
        # Cancel: revoke the restricted session and leave the user signed out.
        AuthenticationLogoutCurrentSession.call(
          resource: @current_client,
          token: current_session,
          reason: "session_limit_cancelled",
        )
        log_out
      end

      return head :no_content if request.format.json?

      redirect_to(auth_app_sign_in_path, status: :see_other)
    end
  end

  private

  def render_expired_restricted_session_locked
    return unless restricted_session_expired?

    render plain: RestrictedSessionGuard::BLOCKED_MESSAGE, status: :locked
  end

  def authentication_credentials_invalid?
    return false if action_name == "show" && current_session_restricted?

    super
  end

  def require_authentication_or_gate
    return if current_session_restricted? || restricted_session_expired?
    return if pending_session_limit_cycle?

    # If logged in with a restricted session, allow access (this is the intended user)
    # If has a valid gate + pending user, allow access.
    # This covers both:
    #   - Not-yet-logged-in users with a gate (e.g., gate issued before JWT set)
    #   - Logged-in users whose restricted status hasn't replicated to the
    #     read replica yet (the gate proves they are in session-limit flow)
    if session_limit_gate_valid? && session[:pending_login_user_id].present?
      return
    end

    # If logged in with an active (non-restricted) session and no gate, deny access.
    # This page is only for users in the restricted session state (3rd login).
    if logged_in?
      head :forbidden
      return
    end

    redirect_to_login
  end

  def pending_session_limit_cycle?
    current_db_sign_in_flow_for_sequence&.sign_in_session_limit_pending?
  end

  def pending_oidc_session_limit_cycle?
    pending_session_limit_cycle? && oidc_authorization_login_challenge.present?
  end

  def redirect_to_login
    redirect_to(
      auth_app_sign_in_path,
      status: :see_other,
    )
  end

  def redirect_to_return_path
    return_path = retrieve_pt || session_limit_pt
    consume_session_limit_gate!

    if return_path.present?
      destination = path_from_signed_pt(signed_pt_token(return_path)) || base_app_identity_url(
        ri: current_region_identifier,
        host: base_authority_host,
      )
      redirect_to_pt_destination!(destination)
    else
      redirect_to_jump_url(
        base_app_identity_url(ri: current_region_identifier, host: base_authority_host, protocol: "https"),
      )
    end
  end

  def resolve_current_client
    # Prefer current_resource (logged in user)
    return current_resource if current_resource

    # Fall back to pending user from gate
    user_id = session[:pending_login_user_id]
    Client.find_by(id: user_id) if user_id
  end

  def load_session_data
    @current_client = resolve_current_client
    return unless @current_client

    @active_sessions = @current_client.client_tokens.active_status.order(created_at: :desc)
    @restricted_sessions = @current_client.client_tokens.restricted_status.order(created_at: :desc)
    @current_session_public_id = current_session_public_id
  end

  # The session management page. Every string, timestamp and URL is finished here; the signed ref
  # is the only session identifier that crosses, and it is the same opaque value the ERB radio
  # button carried.
  def session_page_props
    active_sessions = @active_sessions.to_a
    restricted_sessions = @restricted_sessions.to_a

    {
      title: I18n.t("sign.app.in.session.title"),
      heading: I18n.t("sign.app.in.session.title"),
      description: I18n.t("sign.app.in.session.description"),
      alert: @session_alert.presence,
      notice: @session_notice.presence,
      restricted_notice: current_session_restricted? ? I18n.t("sign.app.in.session.restricted_notice") : nil,
      form: {
        action: auth_app_sign_in_session_path,
        submit_label: I18n.t("sign.app.in.session.revoke_selected"),
      },
      cancel: {
        action: auth_app_sign_in_session_path,
        label: I18n.t("sign.app.in.session.cancel_logout"),
        confirm: I18n.t("sign.app.in.session.cancel_logout_confirm"),
      },
      active_sessions: active_sessions.any? ? active_sessions_props(active_sessions) : nil,
      restricted_sessions: restricted_sessions.any? ? restricted_sessions_props(restricted_sessions) : nil,
    }
  end

  def active_sessions_props(sessions)
    {
      heading: I18n.t("sign.app.in.session.active_sessions"),
      count_label: "(#{sessions.count}/#{ClientToken::MAX_SESSIONS_PER_USER})",
      revoke_label: I18n.t("sign.app.in.session.revoke"),
      items: sessions.map do |session|
        session_item_props(session, label: I18n.t("sign.app.in.session.session_label"), revocable: true)
      end,
    }
  end

  def restricted_sessions_props(sessions)
    {
      heading: I18n.t("sign.app.in.session.restricted_sessions"),
      items: sessions.map do |session|
        session_item_props(session, label: I18n.t("sign.app.in.session.pending_session"), revocable: false)
      end,
    }
  end

  def session_item_props(session, label:, revocable:)
    current = session.public_id == @current_session_public_id

    {
      label: label,
      current: current,
      current_label: current ? I18n.t("sign.app.in.session.current") : nil,
      created_at_label: I18n.t("sign.app.in.session.created_at"),
      created_at: l(session.created_at, format: :short),
      last_used_at_label: session.last_used_at ? I18n.t("sign.app.in.session.last_used_at") : nil,
      last_used_at: session.last_used_at ? l(session.last_used_at, format: :short) : nil,
      ref: (revocable && !current) ? session.signed_ref : nil,
    }
  end

  def can_promote_session?(user)
    # Can promote if active session count is below limit
    active_count =
      AppTicketRecord.connected_to(role: :writing) do
        ClientToken.active_status.where(user_id: user.id).count
      end
    active_count < ClientToken::MAX_SESSIONS_PER_USER
  end

  def promote_current_session!
    return unless current_session&.restricted?

    AppTicketRecord.connected_to(role: :writing) do
      current_session.promote_to_active!
    end
    @current_session = nil # Clear cached session
  end

  def revoke_session_by_ref(user, ref)
    token = ClientToken.find_from_signed_ref(ref)
    unless token && allowed_to?(:destroy?, token, context: { user: user })
      @session_alert = I18n.t("sign.app.in.session.invalid_session")
      return
    end

    # Don't allow revoking the current session via ref (use destroy without ref for that)
    if token.id == current_session&.id || token.public_id == current_session_public_id
      @session_alert = I18n.t("sign.app.in.session.cannot_revoke_current")
      return
    end

    AuthenticationSelectedSessionRevoker.call(
      owner: user,
      token: token,
      current_token: current_session,
      current_session_public_id: current_session_public_id,
      reason: "session_limit_selected_revoke",
    )

    @session_notice = I18n.t("sign.app.in.session.session_revoked")
  end

  def revoke_sessions_by_refs(user, refs)
    revoked_count = 0

    AppTicketRecord.connected_to(role: :writing) do
      ClientToken.transaction do
        ClientToken.find_from_signed_refs(refs).each do |token|
          next unless token && allowed_to?(:destroy?, token, context: { user: user })
          next if token.id == current_session&.id || token.public_id == current_session_public_id # Skip current session

          AuthenticationSelectedSessionRevoker.call(
            owner: user,
            token: token,
            current_token: current_session,
            current_session_public_id: current_session_public_id,
            reason: "session_limit_selected_revoke",
          )
          revoked_count += 1
        end
      end
    end

    revoked_count
  end
end
