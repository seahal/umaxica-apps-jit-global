# typed: false
# frozen_string_literal: true

module Base
  module App
    module Verification
      # Choice of a first authenticator for an actor who has none. GET lists the methods and changes
      # nothing; POST starts one bootstrap transaction for the chosen method. A bootstrap never
      # grants Step-Up freshness: the protected operation asks for an ordinary verification afterwards.
      class SetupsController < Base::App::ApplicationController
        include BaseStepUpIntent
        include SurfaceInertiaPage

        AUTHENTICATION_MODE = :private
        declare_authentication_mode! :private
        REGISTRATION_METHODS = %w(passkey totp email_otp).freeze

        before_action :authenticate_client!

        public

        def show
          authorize!(current_client, to: :show?)
          scope = requested_step_up_scope(StepUpScopeCatalog::APP)
          requested_step_up_return_to(scope: scope, allowed_scopes: StepUpScopeCatalog::APP)
          return redirect_to_ordinary_verification(scope) if available_step_up_methods(current_client).present?
          return render_bootstrap_unavailable unless bootstrap_permitted?(scope)

          render inertia: "base/app/verification/setups/show", props: {
            title: t("sign.app.verification.setup.title"),
            description: t("sign.app.verification.setup.description"),
            methods: REGISTRATION_METHODS.map { |method| { key: method, label: registration_method_label(method) } },
            form: { action: base_app_verification_setup_path(ri: params[:ri]), scope: scope, pt: params[:pt] },
            cancel: { href: base_app_identity_path(ri: params[:ri]), label: t("actions.cancel") },
          }
        end

        def create
          authorize!(current_client, to: :show?)
          scope = requested_step_up_scope(StepUpScopeCatalog::APP)
          return_to = requested_step_up_return_to(scope: scope, allowed_scopes: StepUpScopeCatalog::APP)
          method = params[:registration_method]
          unless method.is_a?(String) && REGISTRATION_METHODS.include?(method) &&
              available_step_up_methods(current_client).blank? && bootstrap_permitted?(scope)
            return render plain: t("errors.messages.invalid_request"), status: :bad_request
          end

          start_bootstrap!(scope: scope, return_to: return_to, method: method)
        end

        private

        def start_bootstrap!(scope:, return_to:, method:)
          issuance = issue_bootstrap_admission!(
            actor: current_client, token: current_session_token, scope: scope, return_to: return_to, method: method,
          )
          return unless issuance

          case method
          when "email_otp"
            redirect_to(new_base_app_identity_emails_registration_path(ri: params[:ri]), status: :see_other)
          when "passkey", "totp"
            redirect_to_surface_url(
              new_auth_app_verification_setup_url(
                entry_ref: issuance.reference, ri: params[:ri],
                host: ENV.fetch("PUBLIC_AUTH_SERVICE_URL"), protocol: "https",
              ), status: :see_other,
            )
          else
            raise ArgumentError, "unsupported registration method: #{method.inspect}"
          end
        end

        def registration_method_label(method)
          case method
          when "passkey" then t("sign.app.verification.setup.methods.passkey")
          when "totp" then t("sign.app.verification.setup.methods.totp")
          when "email_otp" then t("sign.app.verification.setup.methods.email")
          else raise ArgumentError, "unsupported registration method: #{method.inspect}"
          end
        end

        def bootstrap_permitted?(scope)
          current_session_token.established_authentication_method != "secret" &&
            bootstrap_scope_permitted?(scope) && StepUpBootstrapEligibilityQuery.call(actor: current_client)
        end

        def redirect_to_ordinary_verification(scope)
          redirect_to(
            base_app_verification_path(scope: scope, pt: params[:pt], ri: params[:ri]), status: :see_other,
          )
        end

        def render_bootstrap_unavailable
          render plain: t("views.sign.app.verifications.show.no_methods"), status: :unprocessable_content
        end

        def bootstrap_scope_permitted?(scope) = scope != "settings_secret_credential"

        def actor_verification_path(**args)
          base_app_verification_path(**args)
        end
      end
    end
  end
end
