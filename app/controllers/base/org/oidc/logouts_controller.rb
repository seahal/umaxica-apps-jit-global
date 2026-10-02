# typed: false
# frozen_string_literal: true

module Base
  module Org
    module Oidc
      class LogoutsController < Base::Org::ApplicationController
        include CommonRedirect
        include ::AuthenticationLogoutable
        include SignOutNotice
        include SignOidcLogout
        include ::SurfaceInertiaPage

        COORDINATED_LOGOUT_TRUSTED_ORIGINS = JitHostOriginEnv.trusted_origins(
          ENV.fetch("PUBLIC_AUTH_STAFF_URL"),
          ENV.fetch("PUBLIC_CORE_STAFF_URL"),
          ENV.fetch("PUBLIC_BASE_STAFF_URL"),
        ).freeze
        AUTHENTICATION_MODE = :open
        # `reject_oidc_logout_challenge!` still renders the shared `auth/shared/sign_outs/unavailable`
        # ERB template, which needs the surface ERB layout; the Inertia shell renders only an Inertia
        # response body.
        layout -> { @render_surface_erb_layout ? "base/org/application" : "base/org/inertia" }

        declare_authentication_mode! :open
        # CSRF: ordinary POSTs keep the surface-wide `:header_or_legacy_token` check inherited from
        # the application controller. Do not redeclare `protect_from_forgery` here: Rails keeps one
        # `verify_authenticity_token` callback per controller, so a redeclaration with `only:`/`if:`
        # replaces the inherited check instead of adding to it (that is how plain POSTs once ran with
        # no CSRF check at all; adr/sign-neutral-entry-and-logout-target-authorization.md).
        #
        # A coordinated-logout POST cannot carry this surface's legacy token, because the initiating
        # surface does not share this session. `SignOutNotice#verified_request?` accepts a live,
        # unexpired, unfinalized logout challenge in its place, and the `before_action` below is the
        # Fetch Metadata gate for that POST: Sec-Fetch-Site must be same-origin/same-site and the
        # Origin blank, one of COORDINATED_LOGOUT_TRUSTED_ORIGINS, or `null` bound to the live
        # challenge. Dropping this `before_action` or adding an origin is a security-boundary change
        # that requires explicit human review.
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
          base_org_sign_out_path(ri: ri)
        end

        # The ERB template this action rendered was a two-line wrapper around the shared sign-out
        # confirmation, so both the confirmation and the completion path render the same Inertia
        # page here. The override stays on this controller because the other surfaces still render
        # the shared ERB through the same concern.
        def render_oidc_end_session_confirmation
          render inertia: "base/org/oidc/logouts/show", props: sign_out_edit_page_props, status: :ok
        end

        def render_oidc_logout_completion
          @sign_out_notice = consume_sign_out_notice
          render inertia: "base/org/oidc/logouts/show",
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
