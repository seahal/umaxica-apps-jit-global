# typed: false
# frozen_string_literal: true

module Base
  module App
    class VerificationsController < Base::App::ApplicationController
      include BaseStepUpIntent
      include SurfaceInertiaPage

      AUTHENTICATION_MODE = :private
      declare_authentication_mode! :private

      public

      def show
        authorize!(current_client, to: :show?)
        response.set_header("Cache-Control", "private, no-store")
        return if reject_step_up_for_authentication_context!

        return_target = requested_rp_step_up_return_target
        return redirect_to(return_target, status: :see_other, allow_other_host: false) if current_step_up_evidence

        render inertia: true, props: {
          title: t("sign.app.verification.new.title"),
          description: t("sign.app.verification.new.description"),
          form: {
            action: base_app_verification_path(ri: params[:ri]),
            scope: params[:scope].to_s,
            pt: params[:pt].to_s,
            return_target: return_target,
            submit_label: t("actions.continue"),
          },
          cancel: { href: base_app_identity_path(ri: params[:ri]), label: t("actions.cancel") },
        }
      rescue ActionController::BadRequest
        render plain: I18n.t("errors.messages.invalid_request"), status: :bad_request
      rescue ActiveRecord::ActiveRecordError
        head :service_unavailable
      end

      def create
        authorize!(current_client, to: :show?)
        response.set_header("Cache-Control", "private, no-store")
        return if reject_step_up_for_authentication_context!

        return_target = requested_rp_step_up_return_target
        return redirect_to(return_target, status: :see_other, allow_other_host: false) if current_step_up_evidence

        # An actor without an authenticator chooses one on Base first; nothing is issued here.
        return redirect_to_bootstrap_choice if available_step_up_methods(current_client).blank?

        started = RpStepUpStartIssuer.call(
          cell: RpCellBinding.for_client(oidc_client_id), access_state: browser_rp_access_state,
          actor: current_client, browser_binding: ensure_base_admission_browser_nonce!, return_target: return_target,
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
        render plain: t("sign.app.verification.step_up_refused"), status: :conflict
      rescue ActiveRecord::ActiveRecordError => e
        log_step_up_ceremony(
          "refused",
          outcome: "unavailable",
          reason_code: "persistence_unavailable",
          error_class: e.class.name,
          stage: "rp_start",
        )
        render plain: t("sign.app.verification.step_up_unavailable"), status: :service_unavailable
      end

      private

      def current_step_up_evidence
        StepUpEvidenceResolver.call(
          access_state: browser_rp_access_state, actor: current_client, cell: RpCellBinding.for_client(oidc_client_id),
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
        if scope == "settings_email"
          return_to = resolve_step_up_pt(params[:pt])
          path = URI.parse(return_to).path if return_to.present?
          match = %r{\A/identity/emails/([A-Za-z0-9_-]{21})/edit\z}.match(path.to_s)
          if match
            email = ClientEmail.find_by!(user_id: current_client.id, public_id: match[1])
            return super(scope: scope, **options.merge(resource_ref: email.public_id))
          end
        end

        if scope == "settings_totp"
          return_to = resolve_step_up_pt(params[:pt])
          path = URI.parse(return_to).path if return_to.present?
          match = %r{\A/identity/totps/([A-Za-z0-9_-]{21})\z}.match(path.to_s)
          if match
            credential = current_client.client_totp_credentials.find_by!(public_id: match[1])
            return super(scope: scope, **options.merge(resource_ref: credential.public_id))
          end
        end

        target = additional_step_up_target(scope)
        return super(scope: scope, **options.merge(resource_ref: target)) if target

        super
      end

      def additional_step_up_target(scope)
        return unless %w(settings_passkey settings_secret_credential settings_telephone).include?(scope)

        return_to = resolve_step_up_pt(params[:pt])
        path = URI.parse(return_to).path if return_to.present?
        issuance_match = %r{\A/secret_issuances/([A-Za-z0-9_-]{21})\z}.match(path.to_s)
        if issuance_match && %w(settings_passkey settings_secret_credential).include?(scope)
          issuance = ClientSecretIssuance.find_by!(
            public_id: issuance_match[1], client_id: current_client.id,
            browser_session_ref: current_session_token.public_id, sign_up_flow_ref: nil,
          )
          expected_scope = (issuance.origin == "manual") ? "settings_secret_credential" : "settings_passkey"
          raise ActionController::BadRequest, "Secret issuance scope mismatch" unless scope == expected_scope

          return issuance.public_id
        end
        case scope
        when "settings_passkey"
          match = %r{\A/identity/passkeys/([A-Za-z0-9_-]{21})\z}.match(path.to_s)
          return current_client.client_passkeys.active.find_by!(public_id: match[1]).public_id if match
        when "settings_secret_credential"
          match = %r{\A/secrets/([A-Za-z0-9_-]{21})(?:/edit)?\z}.match(path.to_s)
          return current_client.client_secret_credentials.find_by!(public_id: match[1]).public_id if match
        when "settings_telephone"
          match = %r{\A/identity/telephones/([A-Za-z0-9_-]{21})/edit\z}.match(path.to_s)
          return current_client.client_telephones.find_by!(public_id: match[1]).public_id if match
        end
        nil
      end

      def redirect_to_bootstrap_choice
        return if reject_step_up_for_authentication_context!

        scope = requested_step_up_scope(StepUpScopeCatalog::APP)
        requested_step_up_return_to(scope: scope, allowed_scopes: StepUpScopeCatalog::APP)
        if current_session_token.established_authentication_method == "secret"
          return render plain: t("errors.messages.invalid_request"), status: :bad_request
        end

        redirect_to(
          base_app_verification_setup_path(scope: scope, pt: params[:pt], ri: params[:ri]), status: :see_other,
        )
      end

      def bootstrap_registration_methods = %i(passkey totp)

      def bootstrap_scope_permitted?(scope) = scope != "settings_secret_credential"

      def actor_verification_path(**args)
        base_app_verification_path(**args)
      end
    end
  end
end
