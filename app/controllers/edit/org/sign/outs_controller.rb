# typed: false
# frozen_string_literal: true

module Edit
  module Org
    module Sign
      class OutsController < Edit::Org::BareController
        include ::AuthenticationClient
        include ::AuthenticationLogoutable
        include ::SignOutNotice
        include ::OidcRpLogoutLauncher

        AUTHENTICATION_MODE = :open
        layout "edit/org/application"

        before_action :authenticate!, only: :create
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
          render "auth/shared/sign_outs/edit"
        end

        def create
          launch_oidc_rp_logout!(
            client_id: "edit-org",
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
