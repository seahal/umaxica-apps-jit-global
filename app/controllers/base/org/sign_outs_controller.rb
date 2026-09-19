# typed: false
# frozen_string_literal: true

module Base
  module Org
    class SignOutsController < Base::Org::ApplicationController
      include ::AuthenticationLogoutable
      include ::SignOutNotice
      include ::SignOidcLogout
      include ::BaseSignOutDestination
      include ::SurfaceInertiaPage

      AUTHENTICATION_MODE = :open
      # `reject_oidc_logout_challenge!` still renders the shared `auth/shared/sign_outs/unavailable`
      # ERB template, which needs the surface ERB layout; the Inertia shell renders only an Inertia
      # response body.
      layout -> { @render_surface_erb_layout ? "base/org/application" : "base/org/inertia" }

      declare_authentication_mode! :open
      after_action :sign_out_notice_cache_headers!, only: %i(edit create)

      def new
        redirect_to(sign_out_edit_path, status: :see_other)
      end

      def edit
        render inertia: "base/org/sign_outs/edit", props: sign_out_edit_page_props
      end

      def create
        finish_local_sign_out!
      end

      private

      def reject_oidc_logout_challenge!(reason)
        @render_surface_erb_layout = true
        super
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

      def sign_out_confirmation_form_path
        sign_out_post_path
      end
    end
  end
end
