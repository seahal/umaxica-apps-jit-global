# typed: false
# frozen_string_literal: true

module Base
  module Com
    module Verification
      # Choice of a first visitor authenticator. GET is read-only; POST starts exactly the
      # selected bootstrap transaction before handing the browser to the admitted Auth ceremony.
      class SetupsController < Base::Com::ApplicationController
        include BaseStepUpIntent
        include SurfaceInertiaPage

        AUTHENTICATION_MODE = :private
        declare_authentication_mode! :private
        REGISTRATION_METHODS = %w(passkey email_otp).freeze

        public

        def show
          authorize!(current_visitor, to: :show?)
          scope = requested_step_up_scope(StepUpScopeCatalog::COM)
          requested_step_up_return_to(scope: scope, allowed_scopes: StepUpScopeCatalog::COM)
          return redirect_to_ordinary_verification(scope) if available_step_up_methods(current_visitor).present?
          return render_bootstrap_unavailable unless bootstrap_permitted?(scope)

          render inertia: "base/com/verification/setups/show", props: {
            title: t("sign.com.verification.setup.title"),
            description: t("sign.com.verification.setup.description"),
            methods: REGISTRATION_METHODS.map { |method| { key: method, label: registration_method_label(method) } },
            form: { action: base_com_verification_setup_path(ri: params[:ri]), scope: scope, pt: params[:pt] },
            cancel: { href: base_com_identity_path(ri: params[:ri]), label: t("actions.cancel") },
          }
        end

        def create
          authorize!(current_visitor, to: :show?)
          scope = requested_step_up_scope(StepUpScopeCatalog::COM)
          return_to = requested_step_up_return_to(scope: scope, allowed_scopes: StepUpScopeCatalog::COM)
          method = params[:registration_method]
          unless method.is_a?(String) && REGISTRATION_METHODS.include?(method) &&
              available_step_up_methods(current_visitor).blank? && bootstrap_permitted?(scope)
            return render plain: t("errors.messages.invalid_request"), status: :bad_request
          end

          start_bootstrap!(scope: scope, return_to: return_to, method: method)
        end

        private

        def start_bootstrap!(scope:, return_to:, method:)
          issuance = issue_bootstrap_admission!(
            actor: current_visitor, token: current_session_token, scope: scope, return_to: return_to, method: method,
          )
          return unless issuance

          case method
          when "email_otp"
            redirect_to(new_base_com_identity_emails_registration_path(ri: params[:ri]), status: :see_other)
          when "passkey"
            redirect_to_surface_url(
              new_auth_com_verification_setup_url(
                entry_ref: issuance.reference, ri: params[:ri],
                host: ENV.fetch("PUBLIC_AUTH_CORPORATE_URL"), protocol: "https",
              ), status: :see_other,
            )
          else
            raise ArgumentError, "unsupported registration method: #{method.inspect}"
          end
        end

        def registration_method_label(method)
          case method
          when "passkey" then t("sign.com.verification.setup.methods.passkey")
          when "email_otp" then t("sign.com.verification.setup.methods.email")
          else raise ArgumentError, "unsupported registration method: #{method.inspect}"
          end
        end

        def bootstrap_permitted?(scope)
          bootstrap_scope_permitted?(scope) && StepUpBootstrapEligibilityQuery.call(actor: current_visitor)
        end

        def redirect_to_ordinary_verification(scope)
          redirect_to(base_com_verification_path(scope: scope, pt: params[:pt], ri: params[:ri]), status: :see_other)
        end

        def render_bootstrap_unavailable
          render plain: t("views.sign.com.verifications.show.no_methods"), status: :unprocessable_content
        end

        def bootstrap_scope_permitted?(_scope) = true

        def actor_verification_path(**args)
          base_com_verification_path(**args)
        end
      end
    end
  end
end
