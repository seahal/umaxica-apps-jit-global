# typed: false
# frozen_string_literal: true

# Controllers provide step_up_requirement, available_step_up_methods, bootstrap_scope_permitted?,
# bootstrap_registration_methods, step_up_audience and the existing context/transport helpers.
module BaseStepUpIntent
  extend ActiveSupport::Concern

  include StepUpCeremonyLogging
  include BaseStepUpTransactionMarker

  private

  def render_step_up_start!(actor:, token:, allowed_scopes:, title:, description:, action:, cancel:)
    return if reject_step_up_for_authentication_context!

    scope = requested_step_up_scope(allowed_scopes)
    return_to = requested_step_up_return_to(scope: scope, allowed_scopes: allowed_scopes)
    requirement = step_up_requirement(scope: scope)
    if StepUpResolver.call(token: token, requirement: requirement).satisfied?
      return redirect_to(return_to, status: :see_other, allow_other_host: false)
    end

    requested_step_up_requirement(actor: actor, token: token, scope: scope)

    render inertia: true, props: {
      title: title,
      description: description,
      form: { action: action, scope: scope, pt: params[:pt], submit_label: t("actions.continue") },
      cancel: { href: cancel, label: t("actions.cancel") },
    }
  rescue BaseAuthAdmissionCoordinator::Denied => e
    log_step_up_refusal(e, session_public_id: token.public_id, stage: "base_intent_page")
    render plain: I18n.t("views.sign.app.verifications.show.no_methods"), status: :unprocessable_content
  end

  def redirect_to_step_up_ceremony!(actor:, token:, allowed_scopes:, sign_url_builder:, setup_url_builder:)
    return if reject_step_up_for_authentication_context!
    return resolve_step_up_conflict!(actor: actor, token: token) if params[:conflict_action].present?

    scope = requested_step_up_scope(allowed_scopes)
    return_to = requested_step_up_return_to(scope: scope, allowed_scopes: allowed_scopes)
    requirement = step_up_requirement(scope: scope)
    if StepUpResolver.call(token: token, requirement: requirement).satisfied?
      return redirect_to(return_to, status: :see_other, allow_other_host: false)
    end

    requirement = requested_step_up_requirement(actor: actor, token: token, scope: scope)
    ensure_base_admission_browser_nonce!

    issuance = BaseStepUpAdmissionIssuer.call!(
      actor: actor, token: token, requirement: requirement, return_to: return_to,
      base_browser_nonce: base_admission_browser_nonce, base_token: token,
    )
    remember_base_step_up_transaction!(transaction: issuance.transaction, actor:, token:)
    log_step_up_ceremony(
      "admission_issued", transaction: issuance.transaction, outcome: "issued",
                          state_after: issuance.transaction.status,
    )
    redirect_to_surface_url(
      ((requirement.purpose == "bootstrap") ? setup_url_builder : sign_url_builder).call(
        entry_ref: issuance.reference, ri: params[:ri],
      ), status: :see_other,
    )
  rescue BaseAuthAdmissionCoordinator::Denied => e
    log_step_up_refusal(e, session_public_id: token.public_id, stage: "base_admission_issue")
    if e.code == "transaction_conflict"
      render_step_up_conflict!(
        actor: actor, token: token, requirement: requirement, return_to: return_to,
        transaction_ref: e.context.fetch("transaction_ref"),
      )
      return
    end
    # The one refusal the person can resolve: the session is too old to register a first
    # authenticator. Every other refusal stays generic.
    if e.code == "bootstrap_not_fresh"
      return render plain: I18n.t("auth.step_up.fresh_sign_in_required"), status: :forbidden
    end

    render plain: I18n.t("errors.messages.invalid_request"), status: :bad_request
  rescue Umaxica::Valkey::Unavailable, Umaxica::Valkey::OperationError
    render plain: I18n.t("errors.rate_limit.backend_unavailable"), status: :service_unavailable
  end

  # Starts one bootstrap transaction for exactly the chosen registration method. Returns nil after
  # rendering a refusal.
  def issue_bootstrap_admission!(actor:, token:, scope:, return_to:, method:)
    return if reject_step_up_for_authentication_context!
    return resolve_step_up_conflict!(actor: actor, token: token) if params[:conflict_action].present?

    requirement = StepUpRequirement.new(
      scope: scope, purpose: "bootstrap", step_up_required: false, allowed_methods: [method.to_sym],
      phishing_resistant_required: false, user_verification_required: false,
      full_reauthentication_required: false,
      audience: step_up_audience, session_binding: token.public_id, token_binding: token.public_id,
      require_session_binding: true, ttl: VerificationBase::STEP_UP_TTL, actor_ref: actor.public_id,
      resource_ref: nil, tenant_ref: nil,
    )
    ensure_base_admission_browser_nonce!
    issuance = BaseStepUpAdmissionIssuer.call!(
      actor: actor, token: token, requirement: requirement, return_to: return_to,
      base_browser_nonce: base_admission_browser_nonce, base_token: token,
    )
    remember_base_step_up_transaction!(transaction: issuance.transaction, actor:, token:)
    log_step_up_ceremony(
      "admission_issued", transaction: issuance.transaction, outcome: "issued", method: method,
                          state_after: issuance.transaction.status,
    )
    issuance
  rescue BaseAuthAdmissionCoordinator::Denied => e
    log_step_up_refusal(e, session_public_id: token.public_id, stage: "base_bootstrap_issue")
    if e.code == "transaction_conflict"
      render_step_up_conflict!(
        actor: actor, token: token, requirement: requirement, return_to: return_to,
        transaction_ref: e.context.fetch("transaction_ref"),
      )
      return nil
    end
    if e.code == "bootstrap_not_fresh"
      render plain: I18n.t("auth.step_up.fresh_sign_in_required"), status: :forbidden
    else
      render plain: I18n.t("errors.messages.invalid_request"), status: :bad_request
    end
    nil
  rescue Umaxica::Valkey::Unavailable, Umaxica::Valkey::OperationError
    render plain: I18n.t("errors.rate_limit.backend_unavailable"), status: :service_unavailable
    nil
  end

  def render_step_up_conflict!(actor:, token:, requirement:, return_to:, transaction_ref:)
    reference = transaction_ref
    unless reference.is_a?(String) && reference.present? && requirement.is_a?(StepUpRequirement) &&
        base_step_up_transaction_marker(
          reference:, surface: step_up_intent_surface, actor:, token:,
        )
      render plain: I18n.t("errors.messages.invalid_request"), status: :bad_request
      return
    end

    session[:base_step_up_conflict] = {
      "transaction_ref" => reference,
      "actor_ref" => actor.public_id,
      "session_ref" => token.public_id,
      "surface" => step_up_intent_surface,
      "scope" => requirement.scope,
      "return_to" => return_to,
      "purpose" => requirement.purpose,
      "allowed_methods" => requirement.allowed_methods.map(&:to_s),
      "step_up_required" => requirement.step_up_required?,
      "phishing_resistant_required" => requirement.phishing_resistant_required?,
      "user_verification_required" => requirement.user_verification_required?,
      "full_reauthentication_required" => requirement.full_reauthentication_required?,
      "audience" => requirement.audience,
      "token_binding" => requirement.token_binding,
      "require_session_binding" => requirement.require_session_binding,
      "resource_ref" => requirement.resource_ref,
      "tenant_ref" => requirement.tenant_ref,
    }
    render "base/shared/step_up_conflict", layout: false, status: :conflict
  end

  def resolve_step_up_conflict!(actor:, token:)
    action = params[:conflict_action]
    unless %w(continue cancel_and_start).include?(action)
      render plain: I18n.t("errors.messages.invalid_request"), status: :bad_request
      return
    end

    state = session[:base_step_up_conflict]
    unless state.is_a?(Hash) && state["actor_ref"] == actor.public_id && state["session_ref"] == token.public_id &&
        base_step_up_transaction_marker(
          reference: state["transaction_ref"], surface: state["surface"], actor:, token:,
        )
      render plain: I18n.t("errors.messages.invalid_request"), status: :bad_request
      return
    end

    model = step_up_intent_transaction_model(state.fetch("surface"))
    transaction =
      model.connection_owner.connected_to(role: :writing) do
        model.lock.find_by!(
          transaction_id: state.fetch("transaction_ref"), actor_ref: actor.public_id,
          session_ref: token.public_id,
        )
      end
    now = model.database_now
    unless %w(pending verified).include?(transaction.status) && !transaction.expired?(now: now)
      render plain: I18n.t("errors.messages.invalid_request"), status: :bad_request
      return
    end

    ensure_base_admission_browser_nonce!
    issuance =
      if action == "continue"
        BaseAuthAdmissionCoordinator.issue_handoff!(
          transaction: transaction, base_browser_nonce: base_admission_browser_nonce, base_token: token,
        )
      else
        BaseStepUpCancelAndStartCommitter.call!(
          actor: actor, token: token, previous_transaction: transaction,
          requirement: conflict_step_up_requirement(state, token), return_to: state.fetch("return_to"),
          base_browser_nonce: base_admission_browser_nonce, base_token: token,
        )
      end

    remember_base_step_up_transaction!(transaction: issuance.transaction, actor:, token:)
    session.delete(:base_step_up_conflict)
    redirect_to_step_up_conflict_admission!(issuance: issuance, transaction: issuance.transaction)
  rescue BaseAuthAdmissionCoordinator::Denied, IdentityStepUpCeremonyContract::Error,
         ActiveRecord::RecordNotFound, KeyError, ArgumentError => e
    log_step_up_refusal(e, session_public_id: token.public_id, stage: "base_conflict_resolution")
    render plain: I18n.t("errors.messages.invalid_request"), status: :bad_request
  rescue Umaxica::Valkey::Unavailable, Umaxica::Valkey::OperationError
    render plain: I18n.t("errors.rate_limit.backend_unavailable"), status: :service_unavailable
  end

  def redirect_to_step_up_conflict_admission!(issuance:, transaction:)
    surface = transaction.surface
    host_env = {
      "app" => "PUBLIC_AUTH_SERVICE_URL", "com" => "PUBLIC_AUTH_CORPORATE_URL", "org" => "PUBLIC_AUTH_STAFF_URL",
    }.fetch(surface)

    if transaction.purpose == "bootstrap" && transaction.allowed_methods_array == ["email_otp"]
      redirect_to(
        public_send("new_base_#{surface}_identity_emails_registration_path", ri: params[:ri]), status: :see_other,
      )
      return
    end

    route =
      (transaction.purpose == "bootstrap") ? "new_auth_#{surface}_verification_setup_url" :
           "auth_#{surface}_verification_url"
    redirect_to_surface_url(
      public_send(route, entry_ref: issuance.reference, ri: params[:ri], host: ENV.fetch(host_env), protocol: "https"),
      status: :see_other,
    )
  end

  def conflict_step_up_requirement(state, token)
    StepUpRequirement.new(
      scope: state.fetch("scope"), purpose: state.fetch("purpose"),
      step_up_required: state.fetch("step_up_required"), allowed_methods: state.fetch("allowed_methods"),
      phishing_resistant_required: state.fetch("phishing_resistant_required"),
      user_verification_required: state.fetch("user_verification_required"),
      full_reauthentication_required: state.fetch("full_reauthentication_required"),
      audience: state.fetch("audience"), session_binding: token.public_id, token_binding: state.fetch("token_binding"),
      require_session_binding: state.fetch("require_session_binding"), ttl: VerificationBase::STEP_UP_TTL,
      actor_ref: state.fetch("actor_ref"), resource_ref: state["resource_ref"], tenant_ref: state["tenant_ref"],
    )
  end

  def step_up_intent_surface
    case self.class.name
    when /::App::/ then "app"
    when /::Com::/ then "com"
    when /::Org::/ then "org"
    else raise ArgumentError, "unsupported step-up surface"
    end
  end

  def step_up_intent_transaction_model(surface)
    {
      "app" => ClientStepUpCeremonyTransaction,
      "com" => VisitorStepUpCeremonyTransaction,
      "org" => OperatorStepUpCeremonyTransaction,
    }.fetch(surface)
  end

  def requested_step_up_scope(allowed_scopes)
    scope = params[:scope].to_s
    raise ActionController::BadRequest, "invalid scope" unless allowed_scopes.key?(scope)

    scope
  end

  def requested_step_up_return_to(scope:, allowed_scopes:)
    return_to = resolve_step_up_pt(params[:pt])
    raise ActionController::BadRequest, "invalid pt" if return_to.blank?
    raise ActionController::BadRequest, "scope mismatch" unless return_to.match?(allowed_scopes.fetch(scope))

    return_to
  end

  def requested_step_up_requirement(actor:, token:, scope:)
    methods = available_step_up_methods(actor)
    return step_up_requirement(scope: scope, allowed_methods: methods) if methods.present?
    unless bootstrap_scope_permitted?(scope) && StepUpBootstrapEligibilityQuery.call(actor: actor)
      raise BaseAuthAdmissionCoordinator::Denied.new("configured methods unavailable", code: "unsupported_method")
    end

    StepUpRequirement.new(
      scope: scope, purpose: "bootstrap", step_up_required: false, allowed_methods: bootstrap_registration_methods,
      phishing_resistant_required: false, user_verification_required: false,
      full_reauthentication_required: false,
      audience: step_up_audience, session_binding: token.public_id, token_binding: token.public_id,
      require_session_binding: true, ttl: VerificationBase::STEP_UP_TTL, actor_ref: actor.public_id,
      resource_ref: nil, tenant_ref: nil,
    )
  end
end
