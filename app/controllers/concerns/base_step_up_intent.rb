# typed: false
# frozen_string_literal: true

# Controllers provide step_up_requirement, available_step_up_methods, bootstrap_scope_permitted?,
# bootstrap_registration_methods, step_up_audience and the existing context/transport helpers.
module BaseStepUpIntent
  extend ActiveSupport::Concern

  include StepUpCeremonyLogging

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

    scope = requested_step_up_scope(allowed_scopes)
    return_to = requested_step_up_return_to(scope: scope, allowed_scopes: allowed_scopes)
    requirement = step_up_requirement(scope: scope)
    if StepUpResolver.call(token: token, requirement: requirement).satisfied?
      return redirect_to(return_to, status: :see_other, allow_other_host: false)
    end

    requirement = requested_step_up_requirement(actor: actor, token: token, scope: scope)

    issuance = BaseStepUpAdmissionIssuer.call!(
      actor: actor, token: token, requirement: requirement, return_to: return_to,
    )
    session[:base_step_up_transaction_ref] = issuance.transaction.transaction_id
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

    requirement = StepUpRequirement.new(
      scope: scope, purpose: "bootstrap", step_up_required: false, allowed_methods: [method.to_sym],
      audience: step_up_audience, session_binding: token.public_id, token_binding: token.public_id,
      require_session_binding: true, ttl: VerificationBase::STEP_UP_TTL,
    )
    issuance = BaseStepUpAdmissionIssuer.call!(
      actor: actor, token: token, requirement: requirement, return_to: return_to,
    )
    session[:base_step_up_transaction_ref] = issuance.transaction.transaction_id
    log_step_up_ceremony(
      "admission_issued", transaction: issuance.transaction, outcome: "issued", method: method,
                          state_after: issuance.transaction.status,
    )
    issuance
  rescue BaseAuthAdmissionCoordinator::Denied => e
    log_step_up_refusal(e, session_public_id: token.public_id, stage: "base_bootstrap_issue")
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
      audience: step_up_audience, session_binding: token.public_id, token_binding: token.public_id,
      require_session_binding: true, ttl: VerificationBase::STEP_UP_TTL,
    )
  end
end
