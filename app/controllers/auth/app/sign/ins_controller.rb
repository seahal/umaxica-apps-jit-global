# typed: false
# frozen_string_literal: true

module Auth
  module App
    module Sign
      class InsController < ::Auth::App::ApplicationController
        include ::SurfaceInertiaPage
        include ::AuthenticationModeSwitchGuard

        AUTHENTICATION_MODE = :guest
        declare_authentication_mode! :guest

        def show
          return redirect_logged_in_direct_entry! if logged_in? && params[:login_challenge].blank?
          return render_method_selection! if params[:login_challenge].blank?

          transaction = load_sign_in_authorization_transaction!
          return redirect_signed_in_authorization_transaction!(transaction) if logged_in?

          session[:oidc_authorization_login_challenge] = transaction.login_challenge
          @oidc_authorization_intent = transaction.intent
          render_method_selection!
        rescue ActiveRecord::RecordNotFound
          render plain: I18n.t("errors.messages.invalid_request"),
                 status: :bad_request
        end

        private

        # Direct entry without an authorization transaction lists the sign-in methods instead of
        # bouncing through Base. Every method page it links to is already reachable directly, and
        # AuthenticationSequenceGate already branches on a missing
        # `oidc_authorization_login_challenge` after login, so no ceremony state is skipped here.
        def render_method_selection!
          render inertia: "auth/app/sign_ins/new", props: method_selection_props
        end

        def method_selection_props
          scope = "sign.app.authentication.new"

          {
            title: page_t("#{scope}.page_title"),
            description: page_t("#{scope}.description"),
            methods: method_selection_links(scope),
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
            {
              key: "secret_credential",
              label: page_t("#{scope}.links.secret_credential"),
              href: new_auth_app_sign_in_secret_path(pt: pt),
            },
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

        def redirect_logged_in_direct_entry!
          redirect_to(
            base_app_dashboard_url(ri: current_region_identifier, host: base_authority_host),
            allow_other_host: true,
          )
        end

        def redirect_signed_in_authorization_transaction!(transaction)
          session.delete(:oidc_authorization_login_challenge)
          result = register_oidc_authorization_result!(transaction.login_challenge)
          redirect_to(result.resume_url, allow_other_host: true)
        end

        def load_sign_in_authorization_transaction!
          transaction =
            OidcAuthorizationTransactionCoordinator.find_by_login_challenge!(
              surface: "app",
              login_challenge: params[:login_challenge].to_s,
            )
          raise ActionController::BadRequest,
                "authorization transaction expired" if transaction.login_challenge_expired?
          raise ActionController::BadRequest, "authorization transaction already consumed" if transaction.consumed?
          raise ActionController::BadRequest,
                "authorization transaction intent mismatch" unless transaction.intent == "sign_in"

          transaction
        end
      end
    end
  end
end
