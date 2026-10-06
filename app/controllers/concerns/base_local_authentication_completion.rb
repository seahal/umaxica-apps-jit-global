# frozen_string_literal: true

# Concrete controllers name the flow model, actor loader, policy rule and success/pending
# destinations. The nonce remains exclusively on Base; no Auth cookie is Base authority.
module BaseLocalAuthenticationCompletion
  public

  def show
    apply_base_browser_continuation_headers!
    validate_result_lookup_params!
    render "base/shared/result_continuation", layout: false,
                                              locals: { action_url: request.path,
                                                        result_ref: params[:result_ref],
                                                        transaction_ref: params[:transaction_ref],
                                                        ri: params[:ri], }
  rescue ActionController::BadRequest, ArgumentError
    render plain: I18n.t("errors.messages.invalid_request"), status: :bad_request
  end

  def create
    apply_base_browser_continuation_headers!
    transaction_reference = transaction_reference_param
    locator = session[SignInCycleLocator::SESSION_KEYS.fetch(local_login_surface.to_sym)]
    unless locator.is_a?(Hash) && locator["public_id"] == transaction_reference
      raise BaseAuthAdmissionCoordinator::Denied, "local browser binding missing"
    end

    flow = local_login_flow(transaction_reference)
    binding = LocalAuthenticationResultCoordinator.read_reference!(
      flow: flow, surface: local_login_surface, reference: result_reference_param,
    )
    actor = local_login_actor(flow)
    if logged_in? && !(flow.base_finalized_at && current_session&.id == flow.token_id)
      return render_sign_in_unavailable_while_authenticated
    end

    authorize_local_login!(flow, actor) unless flow.base_finalized_at
    result = LocalAuthenticationSessionCommitter.call(
      controller: self, flow: flow, actor: actor, nonce: locator.fetch("nonce"), binding: binding,
    )
    complete_local_login_response!(result, locator: locator)
  rescue BaseAuthAdmissionCoordinator::Denied, ActiveRecord::RecordNotFound, KeyError,
         AuthenticationBase::SignInFlowIssuanceRejected
    render plain: I18n.t("errors.messages.invalid_request"), status: :bad_request
  rescue Umaxica::Valkey::Unavailable, Umaxica::Valkey::OperationError
    render plain: I18n.t("errors.rate_limit.backend_unavailable"), status: :service_unavailable
  end

  private

  def validate_result_lookup_params!
    result_reference_param
    transaction_reference_param
  end

  def result_reference_param
    value = params[:result_ref]
    raise ActionController::BadRequest unless value.is_a?(String) && value.match?(BaseAuthAdmissionCoordinator::ADMISSION_REFERENCE_PATTERN)

    value
  end

  def transaction_reference_param
    value = params[:transaction_ref]
    raise ActionController::BadRequest unless value.is_a?(String) && value.present?

    value
  end

  def complete_local_login_response!(result, locator:)
    case result.fetch(:status)
    when :success
      # log_in rotates Base's Rails session. Preserve only this browser's locator for a bounded
      # idempotent result retry, without rotating the flow's nonce or reissuing credentials.
      session[SignInCycleLocator::SESSION_KEYS.fetch(local_login_surface.to_sym)] = locator
      redirect_to(local_login_success_path, status: :see_other)
    when :already_finalized
      if current_session&.id == result.fetch(:token_id)
        redirect_to(local_login_success_path, status: :see_other)
      else
        render plain: I18n.t("errors.messages.invalid_request"), status: :conflict
      end
    when :session_limit_pending
      local_login_pending_response
    when :access_locked, :login_forbidden, :dpop_proof_invalid, :invalid_request
      render plain: I18n.t("errors.messages.not_authorized"), status: :forbidden
    else
      raise BaseAuthAdmissionCoordinator::Denied, "unexpected local completion status"
    end
  end
end
