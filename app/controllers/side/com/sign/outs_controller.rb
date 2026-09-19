# typed: false
# frozen_string_literal: true

module Side
  module Com
    module Sign
      class OutsController < Side::Com::BareController
        include ::AuthenticationClient
        include ::AuthenticationLogoutable
        include ::SignOutNotice
        include ::OidcRpLogoutLauncher

        AUTHENTICATION_MODE = :open
        # Bare on purpose, but the sign-out pages are full HTML documents shown to a
        # person, so they need a layout to carry <head> and its title.
        layout "side/com/application"

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
            client_id: "side-com",
            issuer_resource_type: "visitor",
            token_issuer: "visitor",
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
