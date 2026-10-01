# typed: false
# frozen_string_literal: true

module BaseStepUpIntent
  extend ActiveSupport::Concern

  private

  def redirect_to_step_up_ceremony!(surface:, actor:, token:, allowed_scopes:, sign_url_builder:)
    scope = requested_step_up_scope(allowed_scopes)
    return_to = requested_step_up_return_to(scope: scope, allowed_scopes: allowed_scopes)
    methods = requested_step_up_methods(actor)

    issuance = IdentityStepUpCeremonyGrantIssuer.issue!(
      surface: surface,
      actor_ref: actor.public_id,
      session_ref: token.public_id,
      required_scope: scope,
      required_aal: verification_required_aal,
      allowed_methods: methods,
      return_to: return_to,
      expires_at: self.class::STEP_UP_TTL.from_now,
    )

    redirect_to_surface_url(
      sign_url_builder.call(
        scope: scope,
        pt: params[:pt],
        ri: params[:ri],
        step_up_ceremony_grant: issuance.grant,
        step_up_completion_csrf: form_authenticity_token,
      ),
      status: :see_other,
      preserve_query_keys: ["pt"],
    )
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
