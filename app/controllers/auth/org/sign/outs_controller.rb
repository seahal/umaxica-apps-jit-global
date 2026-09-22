# typed: false
# frozen_string_literal: true

module Auth
  module Org
    module Sign
      class OutsController < ::Auth::Org::ApplicationController
        include ::SignOutNotice
        include ::SignOutCancellation
        include ::SurfaceInertiaPage
        include ::SignOutInertiaPages

        AUTHENTICATION_MODE = :open
        declare_authentication_mode! :open
        skip_before_action :transparent_refresh_access_token, raise: false
        helper_method :sign_out_completed_description
        helper_method :sign_out_confirmation_form_path

        after_action :sign_out_notice_cache_headers!, only: %i(show edit)

        def show
          redirect_to_base_sign_out!
        end

        def new
          redirect_to(sign_out_edit_path, status: :see_other)
        end

        def edit
          render_sign_out_confirmation_page
        end

        def create
          return continue_coordinated_sign_out! if params[:logout_challenge].present?

          clear_auth_ceremony_context!
          redirect_to_base_sign_out!
        end

        private

        def continue_coordinated_sign_out!
          clear_auth_ceremony_context!
          transaction = AcmeLogoutTransactionCoordinator.find_by!(logout_challenge: params.expect(:logout_challenge))
          result = AcmeLogoutTransactionCoordinator.advance!(
            logout_challenge: transaction.logout_challenge,
            step: "sign_cleared",
          )
          return render_coordinated_sign_out_unavailable unless result.success?

          render_cross_origin_sign_out_handoff(
            target_url: base_org_oidc_logout_url(
              host: base_authority_host,
              protocol: "https",
            ),
            transaction: transaction,
          )
        end

        def redirect_to_base_sign_out!
          redirect_to(
            base_org_sign_out_url(
              host: base_authority_host,
              protocol: "https",
              ri: params[:ri],
            ),
            status: :see_other,
            allow_other_host: true,
          )
        end

        def render_coordinated_sign_out_unavailable
          render "auth/shared/sign_outs/unavailable", status: :unprocessable_content, layout: false
        end

        def sign_out_confirmation_form_path
          sign_out_post_path
        end
      end
    end
  end
end
