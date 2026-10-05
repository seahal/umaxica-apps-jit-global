# typed: false
# frozen_string_literal: true

module Auth
  module App
    module Sign
      class InsController < ::Auth::App::ApplicationController
        include ::SurfaceInertiaPage
        include ::AuthenticationModeSwitchGuard
        include ::AuthCeremonyAdmission

        AUTHENTICATION_MODE = :guest
        declare_authentication_mode! :guest

        def show
          admit_or_render_sign_ceremony!(expected_intent: auth_ceremony_entry_intent) { render_method_selection! }
        end

        private

        def auth_ceremony_entry_intent = "sign_in"

        def render_method_selection!
          render inertia: "auth/app/sign_ins/new", props: method_selection_props
        end

        def method_selection_props
          scope = "sign.app.authentication.new"

          {
            title: page_t("#{scope}.page_title"),
            description: page_t("#{scope}.description"),
            methods: method_selection_links(scope),
            cancel_label: t("actions.cancel"),
            social_providers: [google_provider_button(scope), apple_provider_button(scope)],
            registration_link: {
              key: "registration",
              label: page_t("#{scope}.links.registration"),
              href: auth_app_sign_up_path(ri: params[:ri], pt: signed_pt_param),
            },
          }
        end

        def method_selection_links(scope)
          pt = signed_pt_param

          [
            { key: "email", label: page_t("#{scope}.links.email"), href: new_auth_app_sign_in_email_path(pt: pt) },
            { key: "passkey",
              label: page_t("#{scope}.links.passkey"),
              href: new_auth_app_sign_in_passkey_path(pt: pt), },
            { key: "device",
              label: page_t("sign.app.authentication.new.links.device"),
              href: auth_app_sign_in_device_path(pt: pt), },
            { key: "secret",
              label: t("sign.app.authentication.new.links.secret"),
              href: new_auth_app_sign_in_secret_url(
                pt: pt, ri: current_region_identifier,
                host: ENV.fetch("PUBLIC_AUTH_SERVICE_URL"),
              ), },
          ]
        end

        # Each provider hand-off is a native document POST whose global authenticity token is
        # verified twice: here, and again at the OmniAuth request phase, which sits at another path.
        # It is the same masked per-session token the ERB form embedded in this same document.
        #
        # Google supplies whole-button artwork that carries its own English wording, so the
        # accessible name matches the artwork rather than the locale. See
        # docs/reference/third-party-sign-in-button-requirements.md.
        def google_provider_button(scope)
          {
            key: "google",
            label: page_t("#{scope}.links.google"),
            action: auth_app_social_google_session_path,
            authenticity_token: form_authenticity_token,
            aria_label: "Sign in with Google",
            artwork: {
              light: "/images/social/google_sign_in_light.svg",
              dark: "/images/social/google_sign_in_dark.svg",
              width: 180,
              height: 40,
            },
            logos: nil,
          }
        end

        # Apple publishes no whole-button artwork for the web, so the button is built to the Human
        # Interface Guidelines: official logo artwork when the deployment carries it, and the title
        # alone otherwise. The guidelines forbid redrawing the mark.
        def apple_provider_button(scope)
          logos = helpers.apple_sign_in_logo_paths

          {
            key: "apple",
            label: page_t("#{scope}.links.apple"),
            action: auth_app_social_apple_session_path,
            authenticity_token: form_authenticity_token,
            aria_label: nil,
            artwork: nil,
            logos: logos && { white: logos[:white], black: logos[:black], width: 28, height: 40 },
          }
        end
      end
    end
  end
end
