# typed: false
# frozen_string_literal: true

module Core
  module App
    module Sign
      class OutsController < Core::App::ApplicationController
        include ::AuthenticationLogoutable
        include ::SignOutNotice
        include ::OidcRpLogoutLauncher

        AUTHENTICATION_MODE = :open
        declare_authentication_mode! :open
        skip_before_action :transparent_refresh_access_token, raise: false

        before_action :authenticate!, only: :create
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
          render "auth/shared/sign_outs/edit"
        end

        def create
          launch_oidc_rp_logout!(
            client_id: "core-app",
            issuer_resource_type: "client",
            token_issuer: "client",
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
