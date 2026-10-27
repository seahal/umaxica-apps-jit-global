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
          clear_auth_ceremony_context!
          redirect_to_base_sign_out!
        end

        private

        def redirect_to_base_sign_out!
          redirect_to_jump_url(
            base_app_sign_out_url(
              host: base_rp_host,
              protocol: "https",
              ri: params[:ri],
            ),
            status: :see_other,
          )
        end

        def sign_out_confirmation_form_path
          sign_out_post_path
        end
      end
    end
  end
end
