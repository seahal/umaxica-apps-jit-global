# typed: false
# frozen_string_literal: true

module Visa
  module Com
    module Oidc
      class LogoutsController < Visa::Com::AuthorityController
        include CommonRedirect
        include ::AuthenticationLogoutable
        include SignOutNotice
        include SignOidcLogout
        include ::SurfaceInertiaPage

        AUTHENTICATION_MODE = :open
        layout -> { @render_surface_erb_layout ? "visa/com/application" : "visa/com/inertia" }

        declare_authentication_mode! :open

        public

        def show
          handle_oidc_end_session_request
        end

        def create
          handle_oidc_end_session_request
        end

        public :create

        private

        def oidc_logout_completed_path(ri:, _sot: nil)
          visa_com_sign_bye_path(ri: ri)
        end

        def sign_out_edit_path(**) = visa_com_oidc_logout_path(**)

        def sign_out_post_path(**options)
          return request.path if options.compact.empty?

          "#{request.path}?#{options.compact.to_query}"
        end

        def sign_out_home_path(**) = visa_com_sign_bye_path(**)

        # The ERB template this action rendered was a two-line wrapper around the shared sign-out
        # confirmation, so both the confirmation and the completion path render the same Inertia
        # page here.
        def render_oidc_end_session_confirmation
          render inertia: "visa/com/oidc/logouts/show", props: sign_out_edit_page_props, status: :ok
        end

        def render_oidc_logout_completion
          @sign_out_notice = consume_sign_out_notice
          render inertia: "visa/com/oidc/logouts/show",
                 props: sign_out_edit_page_props,
                 status: :ok,
                 clear_history: true
        end

        def render_oidc_rp_logout_indeterminate
          render_oidc_logout_result_page(
            title: t("sign.shared.sign_out.indeterminate_title"),
            description: t("sign.shared.sign_out.indeterminate_description"),
            status: :service_unavailable,
          )
        end

        def render_oidc_logout_result_page(title:, description:, status:)
          render inertia: "visa/com/oidc/logouts/show",
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
            action: sign_out_confirmation_form_path,
            submit: t("sign.shared.sign_out.button"),
            ri: params[:ri].presence,
            confirm_description: t("sign.shared.sign_out.confirm_description"),
          }
        end
      end
    end
  end
end
