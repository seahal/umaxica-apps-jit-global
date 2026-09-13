# typed: false
# frozen_string_literal: true

module Auth
  module App
    module Sign
      class OutsController < ::Auth::App::ApplicationController
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

        after_action :sign_out_notice_cache_headers!, only: %i(edit complete)

        def new
          redirect_to(sign_out_edit_path, status: :see_other)
        end

        def edit
          render_sign_out_confirmation_page
        end

        def create
          # Coordinated logout continuation. Core, Side, and Palm origins run a three-step
          # ceremony whose `sign_cleared` hop lands here after Base has cleared its own state,
          # and the one-shot logout challenge is the proof for that cross-host post. A
          # user-initiated sign-out on this surface carries no challenge and starts a fresh
          # RP logout toward the Base end-session endpoint instead.
          return continue_coordinated_sign_out! if params[:logout_challenge].present?

          launch_oidc_rp_logout!(
            client_id: "sign-rp",
            issuer_resource_type: "client",
            token_issuer: "client",
          )
        end

        def complete
          complete_oidc_rp_logout!
        end

        private

        def continue_coordinated_sign_out!
          cookies.delete(AuthenticationBase::REFRESH_COOKIE_KEY)
          logout_current_session!(reason: "user_logout")

          redirect_to(
            base_app_lobby_url(
              host: Rails.configuration.x.boot_config.fetch(:hosts).base_service.host,
              protocol: "https",
              ri: params[:ri],
            ),
            status: :see_other,
            allow_other_host: true,
          )
        end

        def sign_out_confirmation_form_path
          sign_out_post_path
        end
      end
    end
  end
end
