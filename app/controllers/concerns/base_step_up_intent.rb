# typed: false
# frozen_string_literal: true

module BaseStepUpIntent
  extend ActiveSupport::Concern

  private

  def render_step_up_start!(actor:, token:, allowed_scopes:, title:, description:, action:, cancel:)
    scope = requested_step_up_scope(allowed_scopes)
    return_to = requested_step_up_return_to(scope: scope, allowed_scopes: allowed_scopes)
    requirement = step_up_requirement(scope: scope, allowed_methods: requested_step_up_methods(actor))
    if StepUpResolver.call(token: token, requirement: requirement).satisfied?
      return redirect_to(return_to, status: :see_other, allow_other_host: false)
    end

    render inertia: true, props: {
      title: title,
      description: description,
      form: { action: action, scope: scope, pt: params[:pt], submit_label: t("actions.continue") },
      cancel: { href: cancel, label: t("actions.cancel") },
    }
  end

  def redirect_to_step_up_ceremony!(actor:, token:, allowed_scopes:, sign_url_builder:)
    scope = requested_step_up_scope(allowed_scopes)
    return_to = requested_step_up_return_to(scope: scope, allowed_scopes: allowed_scopes)
    requirement = step_up_requirement(scope: scope, allowed_methods: requested_step_up_methods(actor))
    if StepUpResolver.call(token: token, requirement: requirement).satisfied?
      return redirect_to(return_to, status: :see_other, allow_other_host: false)
    end

    issuance = BaseStepUpAdmissionIssuer.call!(
      actor: actor, token: token, requirement: requirement, return_to: return_to,
    )
    session[:base_step_up_transaction_ref] = issuance.transaction.transaction_id
    redirect_to_surface_url(
      sign_url_builder.call(entry_ref: issuance.reference, ri: params[:ri]), status: :see_other,
    )
  rescue BaseAuthAdmissionCoordinator::Denied
    render plain: I18n.t("errors.messages.invalid_request"), status: :bad_request
  rescue Umaxica::Valkey::Unavailable, Umaxica::Valkey::OperationError
    render plain: I18n.t("errors.rate_limit.backend_unavailable"), status: :service_unavailable
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

  def requested_step_up_methods(actor)
    methods = available_step_up_methods(actor)
    raise ActionController::BadRequest, "no step-up method available" if methods.blank?

    methods
  end
end
