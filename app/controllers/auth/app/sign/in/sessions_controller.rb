# typed: false
# frozen_string_literal: true

# Session-limit resolution for a sign-in that is waiting on the concurrent
# session limit (2 active). The waiting sign-in has issued nothing: its verified
# sign-in flow in SESSION_LIMIT_PENDING, located through this browser's
# session, is the only authority this page acts on
# (adr/root-login-establishment-boundary.md).
#
#   - show: list the account's active sessions
#   - update: revoke selected sessions, then complete the pending flow through
#     the final issuance boundary when the limit allows it
#   - destroy: revoke one session by signed ref, or cancel the pending flow
#
# Routes:
#   GET    /in/session  -> #show
#   PATCH  /in/session  -> #update
#   DELETE /in/session  -> #destroy
class Auth::App::Sign::In::SessionsController < ::Auth::App::ApplicationController
  include SessionLimitGate
  include ::SurfaceInertiaPage

  AUTHENTICATION_MODE = :deny_all

  # `update` and `destroy` also answer with the session management page, so the component cannot be
  # derived from the action name.
  SESSION_PAGE_COMPONENT = "auth/app/sign/in/sessions/show"

  declare_authentication_mode! :open

  before_action :require_authentication_or_gate
  ensure_fqdn_gate_first!
  # Restores the inherited default no-store ahead of the gate (DefaultNoStore).
  prepend_before_action :apply_default_no_store

  # Display the account's active sessions
  def show
    load_session_data
    render inertia: SESSION_PAGE_COMPONENT, props: session_page_props
  end

  # Revoke selected sessions and complete the pending sign-in when the limit allows it
  def update
    @current_client = resolve_current_client
    return redirect_to_login unless @current_client

    if pending_oidc_session_limit_cycle?
      render plain: I18n.t("errors.messages.invalid_request"), status: :conflict
      return
    end

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

    # The pending flow is the only thing to complete. log_in re-counts the
    # limit under the actor lock; while it is still full nothing is issued
    # and the page is shown again.
    if pending_session_limit_cycle? && promote_current_session_limit_cycle!(@current_client)
      consume_session_limit_gate!
      return redirect_to_sign_in_sequence!(
        pt: retrieve_pt.presence || session_limit_pt,
      )
    end

    # Still at the limit, stay on session management
    @session_notice = I18n.t("sign.app.in.session.sessions_revoked")
    load_session_data
    render inertia: SESSION_PAGE_COMPONENT, props: session_page_props
  end

  # Cancel the pending sign-in or revoke a specific session
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
      # Cancelling ends only this pending flow; it issued nothing, and no
      # other session of the account is touched.
      flow = current_db_sign_in_flow_for_sequence
      with_sign_in_flow_writing(flow) { flow.fail_sign_in! } if flow&.sign_in_session_limit_pending?
      consume_session_limit_gate!
      clear_current_sign_in_flow_locator!

      return head :no_content if request.format.json?

      redirect_to(auth_app_sign_in_path, status: :see_other)
    end
  end

  private

  # Only a verified sign-in flow waiting on the session limit opens this page.
  # A signed-in browser has nothing pending here.
  def require_authentication_or_gate
    return if pending_session_limit_cycle?

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

  # The actor is the pending flow's principal, read from the flow this
  # browser's locator names; never a principal id kept in the session.
  def resolve_current_client
    flow = current_db_sign_in_flow_for_sequence
    return unless flow&.sign_in_session_limit_pending?

    principal = with_sign_in_flow_writing(flow) { flow.principal }
    principal if principal.is_a?(Client)
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
