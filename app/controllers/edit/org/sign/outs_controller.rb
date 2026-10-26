# typed: false
# frozen_string_literal: true

module Edit
  module Org
    module Sign
      class OutsController < Edit::Org::BareController
        include ::BrowserRpAuthentication
        include ::AuthenticationWithdrawalGate

        include ::AuthenticationLogoutable
        include ::SignOutNotice
        include ::OidcRpLogoutLauncher
        include ::SignOutClearSiteData
        include ::SignErrorResponses

        rescue_from ActionController::InvalidCrossOriginRequest, with: :handle_csrf_failure

        AUTHENTICATION_MODE = :open
        after_action :verify_private_action_authorized!
        after_action :apply_authenticated_page_cache_policy!
        helper_method :current_resource, :browser_rp_authenticated?, :browser_rp_session_public_id,
                      :current_browser_session_security_context, :current_session_public_id,
                      :current_session, :logged_in?

        # OidcRpLogoutLauncher prepends its own callback and re-runs ensure_fqdn_gate_first!; restore
        # the inherited default no-store ahead of the gate (DefaultNoStore).
        prepend_before_action :apply_default_no_store

        layout "edit/org/application"

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
          render "auth/shared/sign_outs/edit"
        end

        def create
          launch_oidc_rp_logout!(
            client_id: "edit-org-ww",
            issuer_resource_type: "operator",
            token_issuer: "operator",
            session_authority: :rp_session,
          )
        end

        private

        def oidc_client_id
          "edit-org-ww"
        end

        def browser_rp_client_id
          "edit-org-ww"
        end

        def browser_rp_resource_type
          "operator"
        end

        def sign_out_confirmation_form_path
          sign_out_post_path
        end
      end
    end
  end
end
