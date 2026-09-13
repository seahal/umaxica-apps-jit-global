# typed: false
# frozen_string_literal: true

module Auth
  module Com
    module Sign
      class InsController < ::Auth::Com::ApplicationController
        include ::SurfaceInertiaPage
        include ::AuthenticationModeSwitchGuard

        AUTHENTICATION_MODE = :guest
        declare_authentication_mode! :guest, no_redirect: true

        def show
          return reject_logged_in_direct_entry! if logged_in? && params[:login_challenge].blank?
          return render_method_selection! if params[:login_challenge].blank?

          transaction =
            OidcAuthorizationTransactionCoordinator.find_by_login_challenge!(
              surface: "com",
              login_challenge: params[:login_challenge].to_s,
            )
          raise ActionController::BadRequest,
                "authorization transaction expired" if transaction.login_challenge_expired?
          raise ActionController::BadRequest, "authorization transaction already consumed" if transaction.consumed?
          raise ActionController::BadRequest,
                "authorization transaction intent mismatch" unless transaction.intent == "sign_in"

          session[:oidc_authorization_login_challenge] = transaction.login_challenge
          @oidc_authorization_intent = transaction.intent
          render inertia: "auth/com/sign_ins/new", props: sign_in_method_props
        rescue ActiveRecord::RecordNotFound
          render plain: I18n.t("errors.messages.invalid_request"),
                 status: :bad_request
        end

        private

        def reject_logged_in_direct_entry!
          render_sign_in_unavailable_while_authenticated
        end

        # Direct entry without an authorization transaction renders this surface's entry page instead
        # of bouncing through Base. Every page it links to is already reachable directly, and the
        # completion paths branch on a missing `oidc_authorization_login_challenge`.
        def render_method_selection!
          render inertia: "auth/com/sign_ins/new", props: sign_in_method_props
        end

        # The com surface offers no social provider hand-off, so the list is empty rather than a
        # set of buttons React would have to hide.
        def sign_in_method_props
          pt = signed_pt_param

          {
            title: t("sign.com.authentication.new.page_title"),
            description: t("sign.com.authentication.new.description"),
            methods: sign_in_method_links(pt),
            social_providers: [],
            registration_link: {
              key: "registration",
              label: t("sign.com.authentication.new.links.registration"),
              href: auth_com_sign_up_path(ri: params[:ri], pt: pt),
            },
          }
        end

        def sign_in_method_links(pt)
          [
            {
              key: "email",
              label: t("sign.com.authentication.new.links.email"),
              href: new_auth_com_sign_in_email_path(ri: params[:ri], pt: pt),
            },
            {
              key: "passkey",
              label: t("sign.com.authentication.new.links.passkey"),
              href: new_auth_com_sign_in_passkey_path(ri: params[:ri], pt: pt),
            },
            {
              key: "secret_credential",
              label: t("sign.com.authentication.new.links.secret_credential"),
              href: new_auth_com_sign_in_secret_path(ri: params[:ri], pt: pt),
            },
          ]
        end
      end
    end
  end
end
