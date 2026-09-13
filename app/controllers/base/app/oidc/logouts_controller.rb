# typed: false
# frozen_string_literal: true

module Base
  module App
    module Oidc
      class LogoutsController < Base::App::ApplicationController
        include CommonRedirect
        include ::AuthenticationLogoutable
        include SignOutNotice
        include SignOidcLogout
        include ::SurfaceInertiaPage

        AUTHENTICATION_MODE = :open
        COORDINATED_LOGOUT_TRUSTED_ORIGINS = JitHostOriginEnv.trusted_origins(
          ENV.fetch("PUBLIC_AUTH_SERVICE_URL"),
          ENV.fetch("PUBLIC_CORE_SERVICE_URL"),
          ENV.fetch("PUBLIC_BASE_SERVICE_URL"),
          ENV.fetch("PUBLIC_PALM_SERVICE_URL"),
        ).freeze

        # `reject_oidc_logout_challenge!` still renders the shared `auth/shared/sign_outs/unavailable`
        # ERB template, which needs the surface ERB layout; the Inertia shell renders only an Inertia
        # response body.
        layout -> { @render_surface_erb_layout ? "base/app/application" : "base/app/inertia" }

        declare_authentication_mode! :open

        protect_from_forgery using: :header_only,
                             trusted_origins: COORDINATED_LOGOUT_TRUSTED_ORIGINS,
                             with: :exception,
                             only: :create,
                             if: -> { params[:logout_challenge].present? }
        skip_before_action :transparent_refresh_access_token, raise: false
        before_action only: :create do
          verify_coordinated_sign_out_post!(trusted_origins: COORDINATED_LOGOUT_TRUSTED_ORIGINS)
        end

        def create
          show
        end

        private

        def reject_oidc_logout_challenge!(reason)
          @render_surface_erb_layout = true
          super
        end

        def oidc_logout_completed_path(ri:, _sot: nil)
          base_app_lobby_path(ri: ri)
        end

        # The ERB template this action rendered was a two-line wrapper around the shared sign-out
        # confirmation, so both the confirmation and the completion path render the same Inertia
        # page here.
        def render_oidc_end_session_confirmation
          render inertia: "base/app/oidc/logouts/show", props: sign_out_edit_page_props, status: :ok
        end

        def render_oidc_logout_completion
          @sign_out_notice = consume_sign_out_notice
          render inertia: "base/app/oidc/logouts/show",
                 props: sign_out_edit_page_props,
                 status: :ok,
                 clear_history: true
        end

        def sign_out_edit_page_props
          active = sign_out_active_context_present?

          {
            title: t("sign.shared.sign_out.title"),
            active: active,
            description: active ? t("sign.shared.sign_out.confirm_description") :
              t("sign.shared.sign_out.already_signed_out"),
            form: active ? sign_out_confirmation_form : nil,
            home_link: { label: t("sign.shared.sign_out.home_link"), href: sign_out_home_path },
          }
        end

        def sign_out_confirmation_form
          {
            action: sign_out_post_path,
            submit: t("sign.shared.sign_out.button"),
            logout_challenge: params[:logout_challenge].presence,
            confirm_description: t("sign.shared.sign_out.confirm_description"),
          }
        end
      end
    end
  end
end
