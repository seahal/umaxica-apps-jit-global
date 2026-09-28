# typed: false
# frozen_string_literal: true

module Auth
  module Com
    module Verification
      class SetupsController < ::Auth::Com::ApplicationController
        include ::SurfaceInertiaPage

        AUTHENTICATION_MODE = :private

        before_action :authenticate_visitor!

        def new
          authorize!(current_visitor, to: :show?)
          @pt = params[:pt].to_s.presence
          @missing_methods = %i(email_otp passkey) - configured_step_up_methods

          if @missing_methods.empty?
            safe_redirect_to(
              verification_redirect_path(pt: @pt),
              fallback: auth_com_root_path(ri: params[:ri]),
              status: :found,
            )
            return
          end

          render inertia: true, props: verification_setup_props
        end

        private

        def verification_setup_props
          {
            title: t("sign.app.verification.setup.title"),
            description: t("sign.app.verification.setup.description"),
            # Setup is shown only when no Step-Up method exists, so no earlier Step-Up state exists to go
            # back to, and the success continuation (`pt`) is not a Back. The only exit is cancellation.
            cancel: { label: t("actions.cancel"),
                      action: auth_com_verification_cancellation_path(ri: params[:ri]),
                      method: "post", },
            methods: verification_setup_methods,
          }
        end

        def verification_setup_methods
          methods = []

          if @missing_methods.include?(:email_otp)
            methods << {
              key: "email_otp",
              label: t("sign.app.verification.setup.methods.email"),
              href: new_base_com_identity_emails_registration_url(
                ri: params[:ri], pt: @pt, host: base_authority_host,
              ),
            }
          end

          if @missing_methods.include?(:passkey)
            methods << {
              key: "passkey",
              label: t("sign.app.verification.setup.methods.passkey"),
              href: new_auth_com_settings_passkey_path(ri: params[:ri], pt: @pt),
            }
          end

          methods
        end
      end
    end
  end
end
