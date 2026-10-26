# typed: false
# frozen_string_literal: true

module Tech
  module Org
    module Sign
      class OutsController < Tech::Org::ApplicationController
        include ::AuthenticationLogoutable
        include ::SignOutNotice
        include ::OidcRpLogoutLauncher
        include ::SignOutClearSiteData

        prepend_before_action :apply_default_no_store

        AUTHENTICATION_MODE = :open
        helper_method :sign_out_completed_description, :sign_out_confirmation_form_path
        before_action :authenticate_oidc_rp_session!, only: :create
        after_action :sign_out_notice_cache_headers!, only: :show

        public

        def show
          complete_oidc_rp_logout!
        end

        def create
          launch_oidc_rp_logout!(
            client_id: "tech-org-ww",
            issuer_resource_type: "operator",
            token_issuer: "operator",
            session_authority: :rp_session,
          )
        end

        private

        def sign_out_confirmation_form_path
          sign_out_post_path
        end

        # The logout boundary validates an existing RP access or refresh credential itself. A
        # refresh here would make sign-out depend on the Tech capability that may have been revoked.
        def browser_rp_unsafe_request_refresh_enabled?
          false
        end
      end
    end
  end
end
