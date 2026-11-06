# typed: false
# frozen_string_literal: true

module Base
  module Org
    class VerificationsController < Base::Org::ApplicationController
      include BaseStepUpIntent
      include SurfaceInertiaPage

      AUTHENTICATION_MODE = :private
      declare_authentication_mode! :private

      public

      def show
        authorize!(current_operator, to: :show?)
        response.set_header("Cache-Control", "private, no-store")
        return if reject_step_up_for_authentication_context!

        return_target = requested_rp_step_up_return_target
        return redirect_to(return_target, status: :see_other, allow_other_host: false) if current_step_up_evidence

        render inertia: true, props: {
          title: t("sign.org.verification.new.title"),
          description: t("sign.org.verification.new.description"),
          form: {
            action: base_org_verification_path(ri: params[:ri]),
            scope: params[:scope].to_s,
            pt: params[:pt].to_s,
            return_target: return_target,
            submit_label: t("actions.continue"),
          },
          cancel: { href: base_org_identity_path(ri: params[:ri]), label: t("actions.cancel") },
        }
      rescue ActionController::BadRequest
        render plain: I18n.t("errors.messages.invalid_request"), status: :bad_request
      rescue ActiveRecord::ActiveRecordError
        head :service_unavailable
      end

      def create
        authorize!(current_operator, to: :show?)
        response.set_header("Cache-Control", "private, no-store")
        return if reject_step_up_for_authentication_context!

        return_target = requested_rp_step_up_return_target
        return redirect_to(return_target, status: :see_other, allow_other_host: false) if current_step_up_evidence

        return redirect_to_bootstrap_choice if available_step_up_methods(current_operator).blank?

        started = RpStepUpStartIssuer.call(
          cell: RpCellBinding.for_client(oidc_client_id), access_state: browser_rp_access_state,
          actor: current_operator, browser_binding: ensure_base_admission_browser_nonce!, return_target: return_target,
        )
        log_step_up_ceremony(
          "admission_issued", ceremony_ref: StepUpObservabilityDigest.ceremony_ref(started.state_ref),
                              outcome: "issued", state_after: "pending", purpose: "step_up",
        )
        redirect_to_surface_url(started.authorization_url, status: :see_other)
      rescue ActionController::BadRequest, URI::InvalidURIError => e
        log_step_up_ceremony(
          "refused",
          outcome: "refused",
          reason_code: "malformed_request",
          error_class: e.class.name,
          stage: "rp_start",
        )
        render plain: I18n.t("errors.messages.invalid_request"), status: :bad_request
      rescue RpStepUpStartIssuer::Refused => e
        log_step_up_ceremony(
          "refused",
          outcome: "refused",
          reason_code: e.reason_code,
          error_class: e.class.name,
          stage: "rp_start",
        )
        render plain: t("sign.org.verification.step_up_refused"), status: :conflict
      rescue ActiveRecord::ActiveRecordError => e
        log_step_up_ceremony(
          "refused",
          outcome: "unavailable",
          reason_code: "persistence_unavailable",
          error_class: e.class.name,
          stage: "rp_start",
        )
        render plain: t("sign.org.verification.step_up_unavailable"), status: :service_unavailable
      end

      private

      def current_step_up_evidence
        StepUpEvidenceResolver.call(
          access_state: browser_rp_access_state,
          actor: current_operator,
          cell: RpCellBinding.for_client(oidc_client_id),
        )
      end

      def requested_rp_step_up_return_target
        raw = params[:return_target]
        return "/identity" if raw.nil? && params[:pt].blank?

        target = raw.nil? ? resolve_step_up_pt(params[:pt]) : RpTargetLinkUri.normalize(raw)
        raise ActionController::BadRequest, "step-up return target is invalid" unless target

        target = RpTargetLinkUri.normalize(URI.parse(target).path)
        raise ActionController::BadRequest, "step-up return target is invalid" unless target

        target
      rescue URI::InvalidURIError
        raise ActionController::BadRequest, "step-up return target is invalid"
      end

      def step_up_requirement(scope:, **options)
        if scope == "settings_passkey"
          return_to = resolve_step_up_pt(params[:pt])
          path = URI.parse(return_to).path if return_to.present?
          match = %r{\A/identity/passkeys/([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})\z}
            .match(path.to_s)
          if match
            credential = current_operator.staff_passkeys.active.find_by!(external_id: match[1])
            return super(scope: scope, **options.merge(resource_ref: credential.external_id))
          end
        end

        super
      end

      def redirect_to_bootstrap_choice
        return if reject_step_up_for_authentication_context!

        scope = requested_step_up_scope(StepUpScopeCatalog::ORG)
        requested_step_up_return_to(scope: scope, allowed_scopes: StepUpScopeCatalog::ORG)
        redirect_to(
          base_org_verification_setup_path(scope: scope, pt: params[:pt], ri: params[:ri]),
          status: :see_other,
        )
      end

      def bootstrap_registration_methods = [:passkey]

      def bootstrap_scope_permitted?(_scope) = true

      def actor_verification_path(**args)
        base_org_verification_path(**args)
      end
    end
  end
end
