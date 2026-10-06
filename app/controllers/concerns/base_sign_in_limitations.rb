# typed: false
# frozen_string_literal: true

# Shared Base-side session-limit resolution for the three authority realms.
# The browser carries only SessionLimitGate's opaque challenge and binding; the
# child transaction supplies the actor, parent flow and selected-session
# authority.
module BaseSignInLimitations
  extend ActiveSupport::Concern

  public

  def show
    return render_invalid_resolution unless resolution_loaded?

    load_session_inventory
    render inertia: limitation_component, props: limitation_page_props
  end

  def update
    return render_invalid_resolution unless resolution_loaded?

    token = selected_token
    unless token_belongs_to_actor?(token)
      @form_error = I18n.t("session_limit.invalid_session")
      load_session_inventory
      return render_limitation_page(status: :unprocessable_content)
    end

    unless resolve_selected_session(token)
      @form_error = I18n.t("session_limit.invalid_session")
      load_session_inventory
      return render_limitation_page(status: :unprocessable_content)
    end

    if social_resolution?
      complete_local_resolution
    else
      resume_authorization_after_resolution
    end
  end

  def destroy
    return render_invalid_resolution unless resolution_loaded?
    return render_invalid_resolution unless cancel_pending_resolution!

    redirect_to(base_sign_entry_path(ri: params[:ri]), status: :see_other)
  end

  private

  def resolve_selected_session(token)
    return false unless @resolution && @resolution_binding.present?

    @resolution.select_session!(
      actor: @actor,
      challenge: @resolution_challenge,
      session_ref: token.public_id,
      browser_binding_digest: @resolution.class.digest_challenge(@resolution_binding),
    )
    @resolution.resolve!(
      actor: @actor,
      challenge: @resolution_challenge,
      browser_binding_digest: @resolution.class.digest_challenge(@resolution_binding),
    )
    true
  rescue FlowInvalidTransition, ActiveRecord::RecordNotFound
    false
  end

  def cancel_pending_resolution!
    return false unless @resolution && @resolution_binding.present?

    @resolution.cancel!(
      actor: @actor,
      challenge: @resolution_challenge,
      browser_binding_digest: @resolution.class.digest_challenge(@resolution_binding),
    )
    flow = @resolution.sign_in_flow
    flow.cancel_sign_in! unless flow.sign_in_completed? || flow.sign_in_expired? ||
      flow.sign_in_cancelled? || flow.sign_in_halted?
    clear_current_sign_in_flow_locator!
    true
  rescue FlowInvalidTransition, ActiveRecord::RecordNotFound
    false
  end

  def render_limitation_page(status:)
    render inertia: limitation_component, props: limitation_page_props, status: status
  end

  def limitation_page_props
    {
      title: I18n.t("session_limit.edit.page_title"),
      heading: I18n.t("session_limit.edit.title"),
      description: I18n.t("session_limit.edit.description"),
      session_label: I18n.t("session_limit.edit.session_label"),
      error: @form_error.presence,
      notice: @form_notice.presence,
      action: limitation_path,
      cancel_action: limitation_path(resolution_query_parameters),
      submit_label: I18n.t("session_limit.edit.submit"),
      cancel_label: I18n.t("session_limit.edit.cancel_logout"),
      resolution: { field: "resolution_challenge", value: @resolution_challenge },
      sessions: Array(@sessions).map { |session_record| serialize_session(session_record) },
    }
  end

  def serialize_session(session_record)
    {
      session_ref: SessionLimitResolutionTokenRef.issue(session_record),
      restriction_label: session_record.restricted? ? "Restricted" : "Normal",
      created_label: "Created #{l(session_record.created_at, format: :short)}",
      last_used_at: session_record.last_used_at.presence && l(session_record.last_used_at, format: :short),
      revoke_label: I18n.t("session_limit.edit.submit"),
    }
  end

  def load_resolution
    gate = session[SessionLimitGate::GATE_SESSION_KEY]
    gate_challenge = gate.is_a?(Hash) ? gate["resolution_challenge"].to_s : ""
    requested_challenge = params[:resolution_challenge].to_s
    @resolution_challenge = gate_challenge.presence
    return if @resolution_challenge.blank?
    return if requested_challenge.present? && requested_challenge != @resolution_challenge

    @resolution_binding = session_limit_resolution_binding
    @resolution = resolution_transaction_class.find_by(challenge: @resolution_challenge)
    return unless @resolution && @resolution_binding.present?

    @actor = actor_class.find_by(public_id: @resolution.actor_ref)
    @oidc_transaction =
      ticket_record.connected_to(role: :writing) { @resolution.oidc_authorization_transaction }
    flow = @resolution.sign_in_flow
    now = flow.class.database_now
    valid_binding = ActiveSupport::SecurityUtils.secure_compare(
      @resolution.browser_binding_digest,
      @resolution.class.digest_challenge(@resolution_binding),
    )
    valid_parent = flow.principal_id == @actor&.id && !flow.expired?(now) &&
      !flow.sign_in_completed? && !flow.sign_in_cancelled? && !flow.sign_in_halted?
    valid_oidc =
      if @oidc_transaction
        @oidc_transaction.actor_ref == @actor&.public_id && @oidc_transaction.authenticated? &&
          @oidc_transaction.base_finalized_at.nil? && !@oidc_transaction.expired?(now: now) &&
          !@oidc_transaction.login_challenge_expired?(now: now)
      else
        true
      end
    @resolution = nil unless @actor && valid_binding && valid_parent && valid_oidc &&
      (@resolution.open? || @resolution.resolved?)
  end

  def resolution_loaded?
    load_resolution if @resolution.nil? && @resolution_challenge.nil?
    @resolution.present?
  end

  def load_session_inventory
    @sessions =
      ticket_record.connected_to(role: :writing) do
        token_class.active_status.where(actor_foreign_key => @actor.id, :rotated_at => nil)
          .order(created_at: :desc).to_a
      end
  end

  def selected_token
    case token_class.name
    when "ClientToken" then SessionLimitResolutionTokenRef.find_client_token(params[:session_ref])
    when "VisitorToken" then SessionLimitResolutionTokenRef.find_visitor_token(params[:session_ref])
    when "OperatorToken" then SessionLimitResolutionTokenRef.find_operator_token(params[:session_ref])
    else raise FlowConfigurationError, "unsupported session-limit token class"
    end
  end

  def token_belongs_to_actor?(token)
    case token
    when ClientToken then token.user_id == @actor.id && @actor.is_a?(Client)
    when VisitorToken then token.visitor_id == @actor.id && @actor.is_a?(Visitor)
    when OperatorToken then token.staff_id == @actor.id && @actor.is_a?(Operator)
    else false
    end && token.currently_usable?
  end

  def social_resolution?
    @oidc_transaction.nil?
  end

  def complete_local_resolution
    return render_invalid_resolution unless promote_current_session_limit_cycle!(@actor)

    redirect_to(local_login_success_path, status: :see_other)
  rescue BaseAuthAdmissionCoordinator::Denied, ActiveRecord::RecordNotFound,
         ActiveRecord::SoleRecordExceeded, AuthCeremonySession::InvalidTransition
    render_invalid_resolution
  end

  def resume_authorization_after_resolution
    finalization =
      @actor.class.connection_class_for_self.connected_to(role: :writing) do
        @actor.with_lock do
          @oidc_transaction.finalize_base! do |locked, _finalization_time|
            next { status: :invalid_request } if locked.base_finalized_at || !@resolution.resolved?

            login_result = promote_oidc_resolution_session!
            next login_result unless login_result[:status] == :success

            { status: :success, browser_session_ref: current_session.public_id }
          end
        end
      end
    if finalization[:status] == :session_limit_pending
      @resolution = finalization.fetch(:resolution_transaction)
      @resolution_challenge = finalization.fetch(:resolution_challenge)
      @resolution_binding = finalization.fetch(:resolution_binding)
      @form_notice = I18n.t("base.app.sign.in.limitations.capacity_still_full")
      load_session_inventory
      return render_limitation_page(status: :unprocessable_content)
    end
    return render_invalid_resolution unless finalization[:status] == :success

    issue_authorization_code!
  rescue ArgumentError, ActiveRecord::RecordNotFound, FlowInvalidTransition
    render_invalid_resolution
  end

  def promote_oidc_resolution_session!
    login_result = log_in(
      @actor,
      establishment: :root_login,
      sign_in_flow: @resolution.sign_in_flow,
      record_login_audit: true,
      token_kind_id: "BROWSER_WEB",
      require_totp_check: false,
      audit_context: { auth_method: "session_limit_promotion", oidc_client_id: @oidc_transaction.client_id },
      authentication_event_at: @oidc_transaction.authenticated_at,
      established_authentication_method: established_authentication_method_for(@oidc_transaction.auth_method),
      oidc_authorization_transaction: @oidc_transaction,
    )
    login_result
  end

  def issue_authorization_code!
    result = OidcAuthorizeCoordinator.call(
      params: @oidc_transaction.authorize_params,
      resource: @actor,
      session_token: current_session,
      auth_method: @oidc_transaction.auth_method,
      acr: @oidc_transaction.acr,
      authentication_event_at: @oidc_transaction.authenticated_at,
      authorization_transaction_ref: @oidc_transaction.transaction_id,
    )
    if result.success?
      redirect_to_jump_url(result.redirect_url)
    else
      render json: { error: result.error, error_description: result.error_description }, status: :bad_request
    end
  end

  def resolution_query_parameters
    { resolution_challenge: @resolution_challenge }
  end

  def render_invalid_resolution
    render plain: I18n.t("session_limit.gate_expired"), status: :gone
  end

  def session_limit_resolution_binding
    gate = session[SessionLimitGate::GATE_SESSION_KEY]
    return unless gate.is_a?(Hash)

    gate["resolution_binding"].presence
  end
end
