# typed: false
# frozen_string_literal: true

module Auth
  module App
    module Verification
      class SetupsController < ::Auth::App::ApplicationController
        include ::SurfaceInertiaPage

        AUTHENTICATION_MODE = :private

        before_action :authenticate_client!

        def new
          authorize!(current_client, to: :show?)
          @pt = params[:pt].to_s.presence
          @missing_methods = step_up_supported_methods - configured_step_up_methods

          unless @missing_methods.empty?
            render inertia: true, props: setup_page_props
            return
          end

          safe_redirect_to(
            verification_redirect_path(pt: @pt),
            fallback: actor_root_path(ri: params[:ri]),
            status: :found,
          )
        end

        private

        # Only the methods the actor has yet to register are offered; a method they already hold is
        # absent rather than rendered and hidden.
        def setup_page_props
          {
            title: t("sign.app.verification.setup.title"),
            heading: t("sign.app.verification.setup.title"),
            description: t("sign.app.verification.setup.description"),
            # Setup is shown only when no Step-Up method exists, so no earlier Step-Up state exists to go back
            # to, and the success continuation (`pt`) is not a Back. The only exit is cancellation.
            cancel: { label: t("actions.cancel"),
                      action: auth_app_verification_cancellation_path(ri: params[:ri]),
                      method: "post", },
            methods: setup_methods,
          }
        end

        def setup_methods
          links = []

          if @missing_methods.include?(:passkey)
            links << {
              key: "passkey",
              label: t("sign.app.verification.setup.methods.passkey"),
              href: new_auth_app_settings_passkey_path(ri: params[:ri], pt: @pt),
            }
          end

          if @missing_methods.include?(:email_otp)
            links << {
              key: "email_otp",
              label: t("sign.app.verification.setup.methods.email"),
              href: new_base_app_identity_emails_registration_url(
                ri: params[:ri], pt: @pt, host: base_authority_host,
              ),
            }
          end

          if @missing_methods.include?(:totp)
            links << {
              key: "totp",
              label: t("sign.app.verification.setup.methods.totp"),
              href: new_auth_app_settings_totp_path(ri: params[:ri], pt: @pt),
            }
          end

          links
        end
      end
    end
  end
end
