# typed: false
# frozen_string_literal: true

module Visa
  module App
    module Oidc
      class LogoutsController < Visa::App::AuthorityController
        include CommonRedirect
        include ::AuthenticationLogoutable
        include SignOutNotice
        include SignOidcLogout
        include ::OidcRpLogoutAuthority
        include ::SurfaceInertiaPage

        AUTHENTICATION_MODE = :open
        # `reject_oidc_logout_challenge!` still renders the shared `auth/shared/sign_outs/unavailable`
        # ERB template, which needs the surface ERB layout; the Inertia shell renders only an Inertia
        # response body.
        layout -> { @render_surface_erb_layout ? "visa/app/application" : "visa/app/inertia" }

        declare_authentication_mode! :open

        def show
          return show_browser_rp_logout_authority! if browser_rp_logout_challenge?

          handle_oidc_end_session_request
        end

        def create
          return create_browser_rp_logout_authority! if browser_rp_logout_challenge?

          handle_oidc_end_session_request
        end

        public :create

        private

        def reject_oidc_logout_challenge!(reason)
          @render_surface_erb_layout = true
          super
        end

        def oidc_logout_completed_path(ri:, _sot: nil)
          visa_app_sign_bye_path(ri: ri)
        end

        def sign_out_edit_path(**) = visa_app_oidc_logout_path(**)

        def sign_out_post_path(**options)
          return request.path if options.compact.empty?

          "#{request.path}?#{options.compact.to_query}"
        end

        def sign_out_home_path(**) = visa_app_sign_bye_path(**)

        # The ERB template this action rendered was a two-line wrapper around the shared sign-out
        # confirmation, so both the confirmation and the completion path render the same Inertia
        # page here.
        def render_oidc_end_session_confirmation
          render inertia: "visa/app/oidc/logouts/show", props: sign_out_edit_page_props, status: :ok
        end

        def render_oidc_logout_completion
          @sign_out_notice = consume_sign_out_notice
          render inertia: "visa/app/oidc/logouts/show",
                 props: sign_out_edit_page_props,
                 status: :ok,
                 clear_history: true
        end

        # A failure after the parent COMMIT still ends the signed-in session, so it ends on an
        # Inertia page that clears history. An HTML page cannot: inertia_rails drops the session
        # clear flag on any non-redirect response, before the next Inertia page could read it.
        def render_oidc_rp_logout_cleanup_incomplete
          @sign_out_cleanup_incomplete = true
          render_oidc_logout_result_page(
            title: t("sign.shared.sign_out.completed_title"), description: sign_out_completed_description, status: :ok,
          )
        end

        def render_oidc_rp_logout_indeterminate
          render_oidc_logout_result_page(
            title: t("sign.shared.sign_out.indeterminate_title"),
            description: t("sign.shared.sign_out.indeterminate_description"),
            status: :service_unavailable,
          )
        end

        def render_oidc_logout_result_page(title:, description:, status:)
          render inertia: "visa/app/oidc/logouts/show",
                 props: {
                   title: title,
                   active: false,
                   description: description,
                   form: nil,
                   home_link: { label: t("sign.shared.sign_out.home_link"), href: sign_out_home_path },
                 },
                 status: status,
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
            action: request.path,
            submit: t("sign.shared.sign_out.button"),
            logout_challenge: params[:logout_challenge].presence,
            ri: params[:ri].presence,
            confirm_description: t("sign.shared.sign_out.confirm_description"),
          }
        end
      end
    end
  end
end
