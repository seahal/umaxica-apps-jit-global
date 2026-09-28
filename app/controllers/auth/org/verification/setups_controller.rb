# typed: false
# frozen_string_literal: true

module Auth
  module Org
    module Verification
      class SetupsController < ::Auth::Org::ApplicationController
        include ::SurfaceInertiaPage

        AUTHENTICATION_MODE = :private

        before_action :authenticate_operator!

        def new
          authorize!(current_operator, to: :show?)
          @pt = params[:pt].to_s.presence
          @missing_methods = step_up_supported_methods - configured_step_up_methods

          if @missing_methods.empty?
            return safe_redirect_to(
              verification_redirect_path(pt: @pt),
              fallback: actor_root_path(ri: params[:ri]),
              status: :found,
            )
          end

          render inertia: true, props: setup_props
        end

        private

        # Only the methods the operator still has to configure are offered; a method already in
        # place is absent rather than rendered and disabled.
        def setup_props
          {
            title: t("sign.org.verification.setup.title"),
            description: t("sign.org.verification.setup.description"),
            # Setup is shown only when no Step-Up method exists, so no earlier Step-Up state exists to go
            # back to, and the success continuation (`pt`) is not a Back. The only exit is cancellation.
            cancel: { label: t("actions.cancel"),
                      action: auth_org_verification_cancellation_path(ri: params[:ri]),
                      method: "post", },
            methods: if @missing_methods.include?(:passkey)
                       [{
                         key: "passkey",
                         label: t("sign.org.verification.setup.methods.passkey"),
                         href: new_auth_org_settings_passkey_path(ri: params[:ri], pt: @pt),
                       }]
                     else
                       []
                     end,
          }
        end
      end
    end
  end
end
