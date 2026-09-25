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

        # Security exception -- do not widen, relax, or remove without re-reviewing the whole
        # coordinated sign-out path.
        #
        # Every other controller in this repository uses `using: :header_or_legacy_token`. This
        # single action uses `:header_only`, which is STRICTER, not weaker: the legacy Rails
        # authenticity token cannot be carried across the OIDC coordinated-logout hop because the
        # initiating surface does not share this surface's session, so the legacy fallback would
        # only ever fail closed or invite a weaker substitute. Requiring Fetch Metadata removes
        # that ambiguity.
        #
        # The exception is bounded on three axes, and all three must hold:
        #   - `only: :create` -- no other action is affected.
        #   - `if: logout_challenge.present?` -- an ordinary POST without a challenge keeps the
        #     surface-wide `:header_or_legacy_token` protection inherited from
        #     `Base::App::ApplicationController`.
        #   - `trusted_origins:` -- exact configured service origins only, never a wildcard.
        #
        # `:header_only` alone is NOT the authorization decision. `verify_coordinated_sign_out_post!`
        # below runs on the same action and independently requires Sec-Fetch-Site to be
        # same-origin/same-site and the Origin to be blank, trusted, or `null` bound to a live,
        # unexpired, unfinalized logout transaction. Removing either half leaves this endpoint
        # open to cross-site forced logout.
        #
        # Changing `using:` here, broadening `only:`/`if:`, adding an origin to
        # COORDINATED_LOGOUT_TRUSTED_ORIGINS, or dropping the `before_action` is a
        # security-boundary change and requires explicit human review, not an incidental refactor.
        protect_from_forgery using: :header_only,
                             trusted_origins: COORDINATED_LOGOUT_TRUSTED_ORIGINS,
                             with: :exception,
                             only: :create,
                             if: -> { params[:logout_challenge].present? }
        # Second, independent half of the CSRF boundary for the coordinated-logout POST; see the
        # `protect_from_forgery` comment above. Keep this `before_action` paired with it.
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
          base_app_sign_out_path(ri: ri)
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
