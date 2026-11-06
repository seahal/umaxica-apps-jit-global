# typed: false
# frozen_string_literal: true

# Auth navigates to the matching Visa host with a non-authorizing result lookup.
# Continuation resources call the private jobs below after their own GET and browser
# binding checks. Durable transaction binding and finalization state live in PostgreSQL.
# Neither an Auth Origin nor a null Origin substitutes for the continuation contract.
module OidcAuthorizationResultPost
  extend ActiveSupport::Concern

  public

  def create
    raise ArgumentError, "authorization start is required" if params[:ceremony_action].blank?

    case params[:ceremony_action]
    when "start" then start_authorization_from_post!
    when "continue" then continue_authorization_from_post!
    else raise ArgumentError, "unsupported authorization POST purpose"
    end
  rescue BaseAuthAdmissionCoordinator::Denied, ActiveRecord::RecordNotFound,
         OidcClientRegistry::ClientNotFound, OidcClientRegistry::InvalidRedirectUri,
         FlowInvalidTransition, ActiveSupport::MessageVerifier::InvalidSignature, ArgumentError
    render json: { error: "invalid_request", error_description: "invalid authorization request" },
           status: :bad_request
  rescue Umaxica::Valkey::Unavailable, Umaxica::Valkey::OperationError => e
    # A Valkey failure says nothing about the request, so it must not read as a rejected result.
    # The result stays unconsumed and may be retried while it is valid.
    Rails.logger.error(
      JitLogEvent.format(
        "oidc.authorization_result.backend_failure",
        surface: oidc_result_surface,
        error_class: e.class.name,
        request_id: request.request_id,
      ),
    )
    render json: {
      error: "temporarily_unavailable",
      error_description: I18n.t("errors.rate_limit.backend_unavailable"),
    }, status: :service_unavailable
  end

  private

  def start_authorization_from_post!
    validate_authorization_start_parameters!
    raise ArgumentError unless params[:ceremony_action].is_a?(String) && params[:ceremony_action] == "start" &&
      params[:result_ref].blank? && params[:transaction_ref].blank? && params[:result].blank?

    validate_authorization_request!
    return start_oidc_step_up_authorization! if @validated_client.step_up_requested
    return issue_authorization_code!(current_resource_for_oidc_authorization) if authorization_session_sufficient?

    start_authorization_ceremony!
  end

  def start_oidc_step_up_authorization!
    return redirect_login_required! if prompt_none_requested? || !logged_in?

    issuance = OidcStepUpAuthorizationIssuer.call!(
      surface: oidc_result_surface,
      actor: current_resource_for_oidc_authorization,
      token: current_session_token,
      client: @validated_client.client,
      params: authorize_params,
      validated_request: @validated_client,
    )
    if issuance.outcome == :unsatisfiable
      return redirect_authorization_request_error!(
        OidcAuthorizeRequestResolver::UnmetAuthenticationRequirements.new(
          "requested authentication class is not available",
        ),
      )
    end

    route_options = {
      entry_ref: issuance.entry_ref,
      ri: params[:ri],
      host: ENV.fetch(oidc_step_up_auth_host_environment),
      protocol: "https",
    }
    entry_url =
      case oidc_result_surface
      when "app" then auth_app_verification_url(**route_options)
      when "org" then auth_org_verification_url(**route_options)
      else raise ArgumentError, "unsupported OIDC step-up surface"
      end
    redirect_to_jump_url(entry_url, status: :see_other)
  rescue OidcStepUpAuthorizationIssuer::NoActiveGrant
    redirect_login_required!
  end

  def oidc_step_up_auth_host_environment
    { "app" => "PUBLIC_AUTH_SERVICE_URL", "org" => "PUBLIC_AUTH_STAFF_URL" }.fetch(oidc_result_surface)
  end

  def render_silent_sso_continuation!
    token = issue_authorization_continuation(
      operation: :silent_sso,
      expires_at: current_session.discard_at,
      payload: {
        "authorize_params" => authorize_params.to_h.stringify_keys,
        "session_public_id" => current_session.public_id,
      },
    )
    render_authorization_continuation_form!(token)
  end

  def step_up_callback_request?
    %i(step_up_result_ref step_up_cancellation_ref step_up_ticket_ref step_up_context_ref).any? do |key|
      params.key?(key)
    end
  end

  def render_step_up_callback_continuation!
    raise ArgumentError, "HEAD is not accepted at step-up continuation" if request.head?

    return render_step_up_result_continuation! if step_up_result_callback?
    return render_step_up_cancellation_continuation! if step_up_cancellation_callback?

    raise ArgumentError, "step-up callback fields are invalid"
  end

  def step_up_result_callback?
    params[:step_up_result_ref].present? && params[:step_up_cancellation_ref].blank?
  end

  def step_up_cancellation_callback?
    params[:step_up_cancellation_ref].present? && params[:step_up_result_ref].blank?
  end

  def render_step_up_result_continuation!
    context, ticket, transaction = load_step_up_callback_records!
    return redirect_step_up_error!(transaction, error: "login_required") unless logged_in?

    admission = validate_step_up_callback_binding!(context:, ticket:, transaction:)
    payload = BaseAuthAdmissionCoordinator.read_result_reference!(
      reference: params[:step_up_result_ref], surface: oidc_result_surface,
      transaction_ref: ticket.transaction_id, expected_intent: "step_up",
    )
    raise ArgumentError, "step-up result ceremony binding mismatch" unless
      payload.fetch("ceremony_session_ref").to_s == admission.admitted_auth_ceremony_session_id.to_s

    token = issue_authorization_continuation(
      operation: :step_up_result,
      expires_at: [transaction.expires_at, transaction.login_challenge_expires_at, ticket.expires_at].min,
      payload: {
        "context_ref" => context.public_id,
        "ticket_ref" => ticket.transaction_id,
        "result_ref" => params[:step_up_result_ref],
        "result_generation" => payload.fetch("result_generation"),
        "session_public_id" => current_session.public_id,
      },
    )
    render_authorization_continuation_form!(token)
  end

  def render_step_up_cancellation_continuation!
    context, ticket, transaction = load_step_up_callback_records!
    return redirect_step_up_error!(transaction, error: "login_required") unless logged_in?

    validate_step_up_callback_binding!(context:, ticket:, transaction:, cancellation: true)
    handoff = ticket.cancellation_handoff_ciphertext
    unless ticket.cancellation_handoff_ref == params[:step_up_cancellation_ref] && handoff.present?
      raise ArgumentError, "step-up cancellation reference mismatch"
    end

    BaseAuthAdmissionCoordinator.read_cancellation_handoff!(
      handoff:, surface: oidc_result_surface, transaction_ref: ticket.transaction_id,
    )
    token = issue_authorization_continuation(
      operation: :step_up_cancellation,
      expires_at: [transaction.expires_at, ticket.expires_at].min,
      payload: {
        "context_ref" => context.public_id,
        "ticket_ref" => ticket.transaction_id,
        "cancellation_ref" => params[:step_up_cancellation_ref],
        "session_public_id" => current_session.public_id,
      },
    )
    render_authorization_continuation_form!(token)
  end

  def render_authorization_continuation_form!(token)
    apply_base_browser_continuation_headers!
    response.headers["Referrer-Policy"] = "strict-origin"
    render template: "visa/shared/authorization_continuation", layout: false,
           locals: { continuation: token, action_url: authorization_create_path }
  end

  def validate_authorization_start_parameters!
    raise ArgumentError, "HEAD is not accepted at authorization start" if request.head?
    return unless %w(result result_ref transaction_ref cancellation_ref switch_handoff continuation).any? do |key|
      params.key?(key)
    end

    raise ArgumentError, "continuation parameters are not accepted at authorization start"
  end

  def issue_authorization_continuation(operation:, payload:, expires_at:)
    token_expires_at = [60.seconds.from_now, expires_at].min
    raise ArgumentError, "authorization continuation is already expired" unless token_expires_at > Time.current

    Rails.application.message_verifier(:visa_authorization_continuation).generate(
      {
        "surface" => oidc_result_surface,
        "operation" => operation.to_s,
        "continuation_expires_at" => token_expires_at.to_f,
      }.merge(payload),
      purpose: "visa-authorization-#{operation}", expires_at: token_expires_at,
    )
  end

  def complete_authorization_from_post!(claims)
    result_ref = claims.fetch("result_ref")
    transaction_ref = claims.fetch("transaction_ref")
    raise ArgumentError unless result_ref.is_a?(String) &&
      result_ref.match?(AuthAdmissionBinding::REFERENCE_PATTERN) &&
      transaction_ref.is_a?(String) && transaction_ref.present?

    transaction = OidcAuthorizationTransactionCoordinator.find_by_transaction_id!(
      surface: oidc_result_surface, transaction_id: transaction_ref,
    )
    validate_base_result_browser_binding!(transaction)
    validate_authorization_request!(transaction.authorize_params)
    validate_authorization_transaction_ready!(transaction)
    payload = BaseAuthAdmissionCoordinator.read_result_reference!(
      reference: result_ref, surface: oidc_result_surface,
      transaction_ref:, expected_intent: transaction.intent,
    )
    raise ArgumentError, "authorization result generation changed" unless
      payload.fetch("result_generation") == claims.fetch("result_generation")

    resume_authorization!(transaction, result_generation: payload.fetch("result_generation"))
  end

  def cancel_authorization_from_post!(claims)
    cancellation_ref = claims.fetch("cancellation_ref")
    transaction_ref = claims.fetch("transaction_ref")
    raise ArgumentError unless cancellation_ref.is_a?(String) && transaction_ref.is_a?(String)

    transaction = OidcAuthorizationTransactionCoordinator.find_by_transaction_id!(
      surface: oidc_result_surface, transaction_id: transaction_ref,
    )
    validate_base_result_browser_binding!(transaction, cancellation: true)
    validate_authorization_request!(transaction.authorize_params)
    handoff = transaction.cancellation_handoff_ciphertext
    raise ArgumentError, "cancellation reference mismatch" unless
      transaction.cancellation_handoff_ref.present? && transaction.cancellation_handoff_ref == cancellation_ref

    BaseAuthAdmissionCoordinator.read_authorization_cancellation_handoff!(
      handoff:, surface: oidc_result_surface, transaction_ref: transaction.transaction_id,
    )
    transaction.cancel!(cancellation_handoff_digest: BaseAuthAdmissionCoordinator.cancellation_handoff_digest(handoff))
    redirect_to_same_origin_or_jump_url(
      ::OidcAuthorizeCoordinator.error_redirect_url(
        redirect_uri: transaction.redirect_uri, resource_type: resource_type, error: "access_denied",
        state: transaction.state,
      ),
      status: :see_other,
    )
  end

  def switch_authorization_from_post!(claims)
    transaction, target, source_auth_session = BaseAuthAdmissionCoordinator.read_switch_handoff!(
      handoff: claims.fetch("switch_handoff"), surface: oidc_result_surface,
    )
    validate_base_result_browser_binding!(transaction, source_auth_session_id: source_auth_session.id)
    validate_authorization_request!(transaction.authorize_params)
    handoff = BaseAuthAdmissionCoordinator.issue_switch_admission!(
      transaction:, source_auth_session:, base_browser_nonce: base_admission_browser_nonce,
      base_token: current_session_token, target:,
    )
    redirect_to_jump_url(authorization_switch_url(target:, entry_ref: handoff.reference), status: :see_other)
  end

  def continue_authorization_from_post!
    validate_continuation_post_fields!
    claims = read_authorization_continuation!
    raise ActiveSupport::MessageVerifier::InvalidSignature unless claims.is_a?(Hash)

    validate_authorization_continuation!(claims)
    dispatch_authorization_continuation!(claims)
  end

  def validate_continuation_post_fields!
    forbidden = %i(
      result_ref transaction_ref cancellation_ref switch_handoff result step_up_result_ref step_up_ticket_ref
      step_up_context_ref step_up_cancellation_ref
    )
    return unless forbidden.any? { |key| params.key?(key) }

    raise ArgumentError, "continuation POST has unexpected request fields"
  end

  def read_authorization_continuation!
    token = params[:continuation]
    raise ArgumentError, "invalid continuation token" unless token.is_a?(String) && token.present?

    %w(result cancellation switch silent_sso step_up_result step_up_cancellation).filter_map do |operation|
      Rails.application.message_verifier(:visa_authorization_continuation).verified(
        token, purpose: "visa-authorization-#{operation}",
      )
    end.first
  end

  def validate_authorization_continuation!(claims)
    expires_at = claims["continuation_expires_at"]
    raise ArgumentError, "authorization continuation expired" unless
      expires_at.is_a?(Float) && expires_at.finite? && Time.current.to_f < expires_at
    raise ArgumentError, "continuation belongs to another Visa surface" unless
      claims.fetch("surface") == oidc_result_surface
  end

  def dispatch_authorization_continuation!(claims)
    case claims.fetch("operation")
    when "result" then complete_authorization_from_post!(claims)
    when "cancellation" then cancel_authorization_from_post!(claims)
    when "switch" then switch_authorization_from_post!(claims)
    when "silent_sso" then complete_silent_sso_from_post!(claims)
    when "step_up_result" then complete_step_up_from_post!(claims)
    when "step_up_cancellation" then cancel_step_up_from_post!(claims)
    else raise ArgumentError, "unsupported authorization continuation"
    end
  end

  def complete_step_up_from_post!(claims)
    validate_step_up_continuation_session!(claims)
    context, ticket, transaction = load_step_up_callback_records!(
      context_ref: claims.fetch("context_ref"), ticket_ref: claims.fetch("ticket_ref"),
    )
    admission = validate_step_up_callback_binding!(context:, ticket:, transaction:)
    payload = BaseAuthAdmissionCoordinator.read_result_reference!(
      reference: claims.fetch("result_ref"), surface: oidc_result_surface,
      transaction_ref: ticket.transaction_id, expected_intent: "step_up",
    )
    raise ArgumentError, "step-up result generation changed" unless
      Integer(payload.fetch("result_generation").to_s, 10) == Integer(claims.fetch("result_generation").to_s, 10)
    raise ArgumentError, "step-up result ceremony binding mismatch" unless
      payload.fetch("ceremony_session_ref").to_s == admission.admitted_auth_ceremony_session_id.to_s

    result = OidcStepUpAuthorizationCompletionCommitter.call!(
      surface: oidc_result_surface, actor: current_resource_for_oidc_authorization,
      token: current_session_token, context:, ticket:, authorization_transaction: transaction,
      admission_binding: admission, result_payload: payload,
    )
    return redirect_step_up_error!(transaction, error: "login_required") if result == :expired
    return redirect_step_up_error!(transaction, error: "unmet_authentication_requirements") unless
      result == :completed

    issue_authorization_code!(
      current_resource_for_oidc_authorization,
      params_hash: transaction.authorize_params,
      authentication_event_at: ticket.verified_at,
      session_token: current_session,
      auth_method: ticket.method,
      acr: OidcAuthorizeRequestResolver::STEP_UP_ACR,
      authorization_transaction_ref: transaction.transaction_id,
    )
  end

  def cancel_step_up_from_post!(claims)
    validate_step_up_continuation_session!(claims)
    context, ticket, transaction = load_step_up_callback_records!(
      context_ref: claims.fetch("context_ref"), ticket_ref: claims.fetch("ticket_ref"),
    )
    admission = validate_step_up_callback_binding!(context:, ticket:, transaction:, cancellation: true)
    raise ArgumentError, "step-up cancellation reference mismatch" unless
      ticket.cancellation_handoff_ref == claims.fetch("cancellation_ref") &&
        ticket.cancellation_handoff_ciphertext.present?

    BaseAuthAdmissionCoordinator.read_cancellation_handoff!(
      handoff: ticket.cancellation_handoff_ciphertext,
      surface: oidc_result_surface,
      transaction_ref: ticket.transaction_id,
    )
    outcome = OidcStepUpAuthorizationCancellationCommitter.call!(
      surface: oidc_result_surface, actor: current_resource_for_oidc_authorization,
      token: current_session_token, context:, ticket:, authorization_transaction: transaction,
      admission_binding: admission, cancellation_handoff: ticket.cancellation_handoff_ciphertext,
    )
    return render json: { error: "invalid_request", error_description: "authorization transaction expired" },
                  status: :bad_request if outcome == :expired
    raise ArgumentError, "step-up cancellation was refused" unless outcome == :cancelled

    redirect_step_up_error!(transaction, error: "access_denied")
  end

  def load_step_up_callback_records!(context_ref: params[:step_up_context_ref], ticket_ref: params[:step_up_ticket_ref])
    context_model = { "app" => ClientStepUpContext, "org" => OperatorStepUpContext }.fetch(oidc_result_surface)
    ticket_model = {
      "app" => ClientStepUpCeremonyTransaction,
      "org" => OperatorStepUpCeremonyTransaction,
    }.fetch(oidc_result_surface)
    raise ArgumentError, "step-up callback references are invalid" unless
      context_ref.is_a?(String) && context_ref.present? && ticket_ref.is_a?(String) && ticket_ref.present?

    context = context_model.includes(:oidc_authorization_transaction).find_by!(public_id: context_ref)
    ticket = ticket_model.find_by!(transaction_id: ticket_ref, surface: oidc_result_surface)
    transaction = context.oidc_authorization_transaction
    raise ArgumentError, "step-up callback context mismatch" unless
      transaction.surface == oidc_result_surface && transaction.intent == "step_up" &&
        ticket.purpose == "step_up" && ticket.required_scope == OidcAuthorizeRequestResolver::STEP_UP_SCOPE &&
        ticket.resource_ref == context.public_id && context.oidc_authorization_transaction_id == transaction.id

    [context, ticket, transaction]
  end

  def validate_step_up_callback_binding!(context:, ticket:, transaction:, cancellation: false)
    validate_authorization_request!(transaction.authorize_params)
    raise ArgumentError, "authorization request is not a step-up request" unless
      @validated_client.step_up_requested
    raise ArgumentError, "step-up context is not pending" unless context.state_id == context_pending_state_id
    raise ArgumentError, "step-up authorization transaction is not pending" unless transaction.pending?
    raise ArgumentError, "step-up ticket is not available" unless
      cancellation ? ticket.cancellation_handoff_available? : ticket.verified?

    validate_base_admission_binding!(ticket, transaction:, cancellation:)
  end

  def validate_base_admission_binding!(ticket, transaction:, cancellation:)
    BaseAuthAdmissionCoordinator.validate_result_browser_binding!(
      transaction: ticket,
      surface: oidc_result_surface,
      base_browser_nonce: transaction.login_challenge,
      base_token: current_session_token,
      cancellation:,
    )
  end

  def context_pending_state_id
    { "app" => ClientStepUpContextState::PENDING, "org" => OperatorStepUpContextState::PENDING }
      .fetch(oidc_result_surface)
  end

  def validate_step_up_continuation_session!(claims)
    raise ArgumentError, "step-up session changed" unless logged_in? &&
      current_session.public_id == claims.fetch("session_public_id")
  end

  def redirect_step_up_error!(transaction, error:)
    redirect_to_same_origin_or_jump_url(
      ::OidcAuthorizeCoordinator.error_redirect_url(
        redirect_uri: transaction.redirect_uri,
        resource_type: resource_type,
        error: error,
        state: transaction.state,
      ),
      status: :see_other,
    )
  end

  def complete_silent_sso_from_post!(claims)
    authorize_params = claims.fetch("authorize_params")
    raise ArgumentError, "silent SSO session changed" unless logged_in? &&
      current_session.public_id == claims.fetch("session_public_id")

    authorize_params = ActionController::Parameters.new(authorize_params).permit(
      :response_type, :client_id, :redirect_uri, :state, :code_challenge,
      :code_challenge_method, :scope, :nonce, :prompt, :max_age, :claims, :acr_values,
    )
    validate_authorization_request!(authorize_params)
    raise ArgumentError, "authorization session is no longer sufficient" unless authorization_session_sufficient?

    resource = current_resource_for_oidc_authorization
    begin
      write_preference!(operation: :sign_in, actor: resource, submitted: {})
    rescue StandardError => e
      log_visa_preference_write_failure(:sign_in, e)
      return render json: { error: "temporarily_unavailable", error_description: "authorization unavailable" },
                    status: :service_unavailable
    end

    issue_authorization_code!(resource, params_hash: authorize_params)
  end

  def current_resource_for_oidc_authorization
    case oidc_result_surface
    when "app" then current_client
    when "com" then current_visitor
    when "org" then current_operator
    else raise ArgumentError, "unsupported OIDC surface"
    end
  end

  def validate_authorization_transaction_ready!(transaction)
    decision_time = transaction.class.database_now
    if transaction.login_challenge_expired?(now: decision_time) || transaction.expired?(now: decision_time)
      raise ArgumentError, "authorization transaction expired"
    end
    return if transaction.authenticated?
    return if transaction.consumed? && transaction.base_finalized_at.present?

    raise ArgumentError, "authorization transaction is not ready"
  end

  # Includers also define authorization_switch_url(target:, entry_ref:) and resource_type.
  def oidc_result_surface
    raise NotImplementedError, "#{self.class} must define #oidc_result_surface"
  end
end
