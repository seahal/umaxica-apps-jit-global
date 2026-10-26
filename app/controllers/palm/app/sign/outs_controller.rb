# typed: false
# frozen_string_literal: true

module Palm
  module App
    module Sign
      class OutsController < Palm::App::ApplicationController
        include ::AuthenticationLogoutable
        include ::SignOutNotice
        include ::OidcRpLogoutLauncher
        include ::SurfaceInertiaPage
        include ::SignOutInertiaPages

        AUTHENTICATION_MODE = :open
        declare_authentication_mode! :open
        before_action :authenticate_oidc_rp_session!, only: :create
        helper_method :sign_out_completed_description
        helper_method :sign_out_confirmation_form_path

        after_action :sign_out_notice_cache_headers!, only: %i(show edit)

        public

        def show
          complete_oidc_rp_logout!
        end

        def new
          redirect_to(sign_out_edit_path, status: :see_other)
        end

        def edit
          render_sign_out_confirmation_page
        end

        def create
          launch_oidc_rp_logout!(
            client_id: RpDeploymentBindingValue.client_id("palm-app"),
            issuer_resource_type: "client",
            token_issuer: "client",
            session_authority: :rp_session,
          )
        end

        private

        def sign_out_confirmation_form_path
          sign_out_post_path
        end
      end
    end
  end
end
