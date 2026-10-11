# typed: false
# frozen_string_literal: true

module OidcRpLogoutLauncher
  extend ActiveSupport::Concern

  included do
    prepend_before_action :normalize_rp_logout_region!, if: -> { action_name == "create" }
    ensure_fqdn_gate_first!
  end

  private

  def launch_oidc_rp_logout!(client_id:, issuer_resource_type:, token_issuer:)
    completion_region = rp_logout_region
    transaction_options = {
      origin_surface: logout_origin_surface,
      initiating_client_id: client_id,
      completion_url: AcmeLogoutTransactionCoordinator.completion_url_for(
        origin_surface: logout_origin_surface,
        ri: completion_region,
        surface: logout_surface_name,
      ),
      actor_ref: current_resource.try(:public_id),
      session_ref: safe_current_session_public_id_for_logout,
      callback_state: nil,
      surface: logout_surface_name,
    }
    transaction_options[:ri] = completion_region if logout_surface_name == "app"

    transaction_result = AcmeLogoutTransactionCoordinator.issue!(**transaction_options)
    return render_oidc_rp_logout_unavailable unless transaction_result.success?

    transaction = transaction_result.transaction
    log_sign_out_event(
      "auth.sign_out.transaction.issued",
      transaction: transaction,
      user_confirmation_required: true,
      auto_handoff: false,
      cleanup_performed: false,
      result: "issued",
    )

    handoff_oidc_rp_logout!(
      transaction,
      client_id: client_id,
      issuer_resource_type: issuer_resource_type,
      token_issuer: token_issuer,
      completion_region: completion_region,
    )
  end

  def handoff_oidc_rp_logout!(transaction, client_id:, issuer_resource_type:, token_issuer:, completion_region:)
    state = SecureRandom.hex(16)
    id_token_hint = oidc_rp_logout_id_token_hint(
      client_id: client_id,
      issuer_resource_type: issuer_resource_type,
      token_issuer: token_issuer,
    )
    prepare_sign_out_completion_notice!(state: state)
    log_sign_out_event("auth.sign_out.step.started", transaction: transaction, result: "started")
    logout_current_session!(reason: "user_logout")
    log_sign_out_event(
      "auth.sign_out.step.cleaned",
      transaction: transaction,
      cleanup_performed: true,
      result: "cleaned",
    )
    issue_sign_out_notice!
    AcmeLogoutTransactionCoordinator.advance!(logout_challenge: transaction.logout_challenge, step: "origin_cleared")
    log_sign_out_event(
      "auth.sign_out.step.advanced",
      transaction: transaction.reload,
      step_after: transaction.expected_step,
      cleanup_performed: true,
      redirect_target_surface: "acme",
      result: "advanced",
    )

    render_cross_origin_sign_out_handoff(
      target_url: acme_oidc_logout_url(
        ri: completion_region,
        id_token_hint: id_token_hint,
        post_logout_redirect_uri: AcmeLogoutTransactionCoordinator.completion_url_for(
          origin_surface: logout_origin_surface,
          ri: completion_region,
          surface: logout_surface_name,
        ),
        state: state,
        logout_challenge: transaction.logout_challenge,
        protocol: "https",
      ),
      transaction: transaction,
    )
  end

  def complete_oidc_rp_logout!
    return head(:not_found) if sign_out_active_context_present?

    notice_id = session[SignOutNotice::SIGN_OUT_NOTICE_SESSION_KEY]
    return head(:not_found) unless notice_id.is_a?(String) && notice_id.present?

    completion_state = Valkey::AuthState::SignOutNoticeStore.new.read(raw_id: notice_id)
    return head(:not_found) unless completion_state
    return head(:not_found) unless completion_state["face"].to_s == logout_surface_name.to_s

    expected_state = completion_state["state"].to_s
    provided_state = params[:state].to_s
    return head(:not_found) if expected_state.present? && provided_state.blank?
    return head(:not_found) if expected_state.blank? && provided_state.present?
    return head(:not_found) unless expected_state.blank? || expected_state.length == provided_state.length
    return head(:not_found) if expected_state.present? && !ActiveSupport::SecurityUtils.secure_compare(
      expected_state,
      provided_state,
    )

    @sign_out_notice = consume_sign_out_notice
    return head(:not_found) unless @sign_out_notice

    render_oidc_rp_logout_completion
  end

  def oidc_rp_logout_id_token_hint(client_id:, issuer_resource_type:, token_issuer:)
    OidcIdTokenIssuer.call(
      resource: current_resource,
      client: OidcClientRegistry.find!(client_id),
      nonce: "sign-out",
      issuer: OidcIssuer.for_resource_type(issuer_resource_type),
      jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_resource_type(issuer_resource_type),
      subject: OidcSubject.for(current_resource, resource_type: token_issuer),
      sid: safe_current_session_public_id_for_logout,
    )
  end

  def acme_oidc_logout_url(**query)
    region = RequestContextContract.normalize_region(query.delete(:ri).presence || rp_logout_region)
    public_send(
      "base_#{sign_surface_name}_oidc_logout_url",
      host: oidc_base_authority_host,
      ri: region,
      **query,
    )
  end

  def oidc_base_authority_host
    case sign_surface_name
    when "app"
      ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    when "com"
      ENV.fetch("PUBLIC_BASE_CORPORATE_URL")
    when "org"
      ENV.fetch("PUBLIC_BASE_STAFF_URL")
    end
  end

  def oidc_acme_host
    oidc_base_authority_host
  end

  def render_oidc_rp_logout_unavailable
    return render_oidc_rp_logout_completion unless logout_surface_name == "app"

    render "auth/shared/sign_outs/unavailable", status: :unprocessable_content
  end

  def render_oidc_rp_logout_completion
    render "auth/shared/sign_outs/complete", status: :ok
  end

  def rp_logout_region
    RequestContextContract.normalize_region(params[:ri])
  end

  def normalize_rp_logout_region!
    return unless logout_surface_name == "app"

    params[:ri] = rp_logout_region
  end

  def sign_surface_name
    controller_path.split("/").second
  end

  def logout_origin_surface
    origin_surface = controller_path.split("/").first
    (origin_surface == "auth") ? "sign" : origin_surface
  end

  def logout_surface_name
    controller_path.split("/").second
  end
end
