# typed: false
# frozen_string_literal: true

module Auth
  module App
    module Sign
      class OutsController < ::Auth::App::ApplicationController
        include ::SignOutNotice
        include ::SignOutCancellation
        include ::SurfaceInertiaPage
        include ::SignOutInertiaPages

        AUTHENTICATION_MODE = :open
        declare_authentication_mode! :open
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
          # Coordinated logout continuation. Core, Warp, and Palm origins run a three-step
          # ceremony whose `sign_cleared` hop lands here after Base has cleared its own state,
          # and the one-shot logout challenge is the proof for that cross-host post. A
          # user-initiated sign-out on this surface ends only Auth ceremony state and then
          # redirects to Base, which owns authoritative logout.
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
            target_url: base_app_oidc_logout_url(
              host: base_authority_host,
              protocol: "https",
            ),
            transaction: transaction,
          )
        end

        def redirect_to_base_sign_out!
          redirect_to_jump_url(
            base_app_sign_out_url(
              host: base_authority_host,
              protocol: "https",
              ri: params[:ri],
            ),
            status: :see_other,
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
