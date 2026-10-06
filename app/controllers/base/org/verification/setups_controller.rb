# typed: false
# frozen_string_literal: true

module Base
  module Org
    module Verification
      # Choice of the first operator authenticator. Operators may bootstrap passkey only.
      class SetupsController < Base::Org::ApplicationController
        include BaseStepUpIntent
        include SurfaceInertiaPage

        AUTHENTICATION_MODE = :private
        declare_authentication_mode! :private
        REGISTRATION_METHODS = %w(passkey).freeze

        public

        def show
          authorize!(current_operator, to: :show?)
          scope = requested_step_up_scope(StepUpScopeCatalog::ORG)
          requested_step_up_return_to(scope: scope, allowed_scopes: StepUpScopeCatalog::ORG)
          return redirect_to_ordinary_verification(scope) if available_step_up_methods(current_operator).present?
          return render_bootstrap_unavailable unless bootstrap_permitted?(scope)

          render inertia: "base/org/verification/setups/show", props: {
            title: t("sign.org.verification.setup.title"),
            description: t("sign.org.verification.setup.description"),
            methods: REGISTRATION_METHODS.map { |method| { key: method, label: registration_method_label(method) } },
            form: { action: base_org_verification_setup_path(ri: params[:ri]), scope: scope, pt: params[:pt] },
            cancel: { href: base_org_identity_path(ri: params[:ri]), label: t("actions.cancel") },
          }
        end

        def create
          authorize!(current_operator, to: :show?)
          scope = requested_step_up_scope(StepUpScopeCatalog::ORG)
          return_to = requested_step_up_return_to(scope: scope, allowed_scopes: StepUpScopeCatalog::ORG)
          method = params[:registration_method]
          unless method.is_a?(String) && REGISTRATION_METHODS.include?(method) &&
              available_step_up_methods(current_operator).blank? && bootstrap_permitted?(scope)
            return render plain: t("errors.messages.invalid_request"), status: :bad_request
          end

          issuance = issue_bootstrap_admission!(
            actor: current_operator, token: current_session_token, scope: scope, return_to: return_to, method: method,
          )
          return unless issuance

          redirect_to_surface_url(
            new_auth_org_verification_setup_url(
              entry_ref: issuance.reference, ri: params[:ri],
              host: ENV.fetch("PUBLIC_AUTH_STAFF_URL"), protocol: "https",
            ), status: :see_other,
          )
        end

        private

        def registration_method_label(method)
          return t("sign.org.verification.setup.methods.passkey") if method == "passkey"

          raise ArgumentError, "unsupported registration method: #{method.inspect}"
        end

        def bootstrap_permitted?(scope)
          bootstrap_scope_permitted?(scope) && StepUpBootstrapEligibilityQuery.call(actor: current_operator)
        end

        def redirect_to_ordinary_verification(scope)
          redirect_to(base_org_verification_path(scope: scope, pt: params[:pt], ri: params[:ri]), status: :see_other)
        end

        def render_bootstrap_unavailable
          render plain: t("views.sign.org.verifications.show.no_methods"), status: :unprocessable_content
        end

        def bootstrap_scope_permitted?(_scope) = true

        def actor_verification_path(**args)
          base_org_verification_path(**args)
        end
      end
    end
  end
end
