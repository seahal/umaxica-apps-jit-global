# typed: false
# frozen_string_literal: true

# Session-limit resolution for a sign-in that is waiting on the concurrent
# session limit (1 active). The waiting sign-in has issued nothing: its verified
# browser-bound durable resolution transaction is the only authority this page
# acts on
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
class Auth::Org::Sign::In::SessionsController < ::Auth::Org::ApplicationController
  include SessionLimitGate
  include ::SurfaceInertiaPage

  AUTHENTICATION_MODE = :deny_all

  # This controller handles session management for both authenticated staff
  # and staff who are in the process of logging in (with a pending gate).
  declare_authentication_mode! :open

  before_action :require_authentication_or_gate

  # Display the account's active sessions
  def show
    load_session_data
    render inertia: true, props: session_limit_props
  end

  # Revoke selected sessions and complete the pending sign-in when the limit allows it
  def update
    @current_operator = resolve_current_operator
    return redirect_to_login unless @current_operator

    ref = params[:ref]

    if ref.present?
      # Revoke a specific session by signed reference
      revoke_session_by_ref(@current_operator, ref)
    else
      # Revoke selected sessions by signed references
      refs = Array(params[:revoke_refs]).compact_blank
      if refs.empty?
        load_session_data
        return render inertia: "auth/org/sign/in/sessions/show",
                      props: session_limit_props,
                      status: :unprocessable_content
      end

      revoke_sessions_by_refs(@current_operator, refs)
    end

    # The pending flow is the only thing to complete. log_in re-counts the
    # limit under the actor lock; while it is still full nothing is issued
    # and the page is shown again.
    if pending_session_limit_cycle? && promote_current_session_limit_cycle!(@current_operator)
      consume_session_limit_gate!
      return redirect_to_sign_in_sequence!(
        pt: retrieve_pt.presence || session_limit_pt,
      )
    end

    # Still at the limit, stay on session management
    load_session_data
    render inertia: "auth/org/sign/in/sessions/show", props: session_limit_props
  end

  # Cancel the pending sign-in or revoke a specific session
  def destroy
    @current_operator = resolve_current_operator
    return redirect_to_login unless @current_operator

    ref = params[:ref]

    if ref.present?
      # Revoke a specific session by signed reference
      revoke_session_by_ref(@current_operator, ref)
      load_session_data
      render inertia: "auth/org/sign/in/sessions/show", props: session_limit_props
    else
      # Cancelling ends only this pending flow; it issued nothing, and no
      # other session of the account is touched.
      cancel_pending_session_limit_resolution!
      consume_session_limit_gate!
      clear_current_sign_in_flow_locator!

      return head :no_content if request.format.json?

      redirect_to(auth_org_sign_in_path, status: :see_other)
    end
  end

  private

  # Only the signed reference of a session travels, which is what the radio input already carried;
  # the token itself never leaves the server.
  def session_limit_props
    {
      title: t("session_limit.edit.page_title"),
      heading: t("session_limit.edit.title"),
      description: t("session_limit.edit.description"),
      form_action: auth_org_sign_in_session_path,
      active_sessions_heading: t("session_limit.edit.active_sessions"),
      session_label: t("session_limit.edit.session_label"),
      created_at_label: t("session_limit.edit.created_at"),
      last_used_label: t("session_limit.edit.last_used"),
      no_sessions: t("session_limit.edit.no_sessions"),
      submit_label: t("session_limit.edit.submit"),
      cancel_logout_label: t("session_limit.edit.cancel_logout"),
      cancel_logout_confirm: t("session_limit.edit.cancel_logout_confirm"),
      sessions: Array(@active_sessions).map { |token| serialize_session(token) },
    }
  end

  def serialize_session(token)
    {
      ref: token.signed_ref,
      digest: "#{token.public_id.first(8)}...",
      created_at: helpers.localized_session_timestamp(token.created_at),
      last_used_at: helpers.localized_session_timestamp(token.last_used_at),
    }
  end

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
    session_limit_resolution.present?
  end

  def redirect_to_login
    redirect_to(
      auth_org_sign_in_path,
      status: :see_other,
    )
  end

  # The actor is the pending flow's principal, read from the flow this
  # browser's locator names; never a principal id kept in the session.
  def resolve_current_operator
    resolution = session_limit_resolution
    return unless resolution

    Operator.find_by(public_id: resolution.actor_ref)
  end

  def load_session_data
    @current_operator = resolve_current_operator
    return unless @current_operator

    @active_sessions = @current_operator.staff_tokens.active_status.order(created_at: :desc)
    @restricted_sessions = @current_operator.staff_tokens.restricted_status.order(created_at: :desc)
    @current_session_public_id = current_session_public_id
  end

  def revoke_session_by_ref(staff, ref)
    token = OperatorToken.find_from_signed_ref(ref)
    unless token && allowed_to?(:destroy?, token, context: { user: staff })
      return
    end

    # Don't allow revoking the current session via ref (use destroy without ref for that)
    if token.id == current_session&.id || token.public_id == current_session_public_id
      return
    end

    return resolve_child_session!(staff, token) if session_limit_resolution

    AuthenticationSelectedSessionRevoker.call(
      owner: staff,
      token: token,
      current_token: current_session,
      current_session_public_id: current_session_public_id,
      reason: "session_limit_selected_revoke",
    )
  end

  def revoke_sessions_by_refs(staff, refs)
    if session_limit_resolution
      token = OperatorToken.find_from_signed_ref(refs.first)
      return 0 unless token

      return resolve_child_session!(staff, token) ? 1 : 0
    end

    revoked_count = 0

    OrgTicketRecord.connected_to(role: :writing) do
      OperatorToken.transaction do
        OperatorToken.find_from_signed_refs(refs).each do |token|
          next unless token && allowed_to?(:destroy?, token, context: { user: staff })
          next if token.id == current_session&.id || token.public_id == current_session_public_id # Skip current session

          AuthenticationSelectedSessionRevoker.call(
            owner: staff,
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

  def resolve_child_session!(actor, token)
    resolution = session_limit_resolution
    return false unless resolution && session_limit_resolution_binding

    challenge = session[GATE_SESSION_KEY]["resolution_challenge"]
    binding_digest = resolution.class.digest_challenge(session_limit_resolution_binding)
    resolution.select_session!(
      actor: actor,
      challenge: challenge,
      session_ref: token.public_id,
      browser_binding_digest: binding_digest,
    )
    resolution.resolve!(
      actor: actor,
      challenge: challenge,
      browser_binding_digest: binding_digest,
    )
    true
  rescue FlowInvalidTransition, ActiveRecord::RecordNotFound
    false
  end

  def cancel_pending_session_limit_resolution!
    resolution = session_limit_resolution
    if resolution
      actor = Operator.find_by(public_id: resolution.actor_ref)
      binding = session_limit_resolution_binding
      challenge = session[GATE_SESSION_KEY]["resolution_challenge"]
      resolution.cancel!(
        actor: actor,
        challenge: challenge,
        browser_binding_digest: resolution.class.digest_challenge(binding),
      ) if actor && binding
    end

    flow = current_db_sign_in_flow_for_sequence
    if flow && !flow.sign_in_completed? && !flow.sign_in_expired? && !flow.sign_in_cancelled? &&
        !flow.sign_in_halted?
      with_sign_in_flow_writing(flow) { flow.cancel_sign_in! }
    end
    clear_current_sign_in_flow_locator!
  end
end
