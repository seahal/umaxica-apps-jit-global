# typed: false
# frozen_string_literal: true

module Auth
  module Org
    module Sign
      class OutsController < ::Auth::Org::ApplicationController
        include ::AuthenticationLogoutable
        include ::SignOutNotice
        include ::SignOutCancellation
        include ::OidcRpLogoutLauncher
        include ::SurfaceInertiaPage
        include ::SignOutInertiaPages

        AUTHENTICATION_MODE = :open
        declare_authentication_mode! :open
        helper_method :sign_out_completed_description
        helper_method :sign_out_confirmation_form_path

        after_action :sign_out_notice_cache_headers!, only: %i(show edit)

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
            client_id: "sign-rp",
            issuer_resource_type: "operator",
            token_issuer: "operator",
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
