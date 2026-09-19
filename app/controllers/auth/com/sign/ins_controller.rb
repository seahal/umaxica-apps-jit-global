# typed: false
# frozen_string_literal: true

module Auth
  module Com
    module Sign
      class InsController < ::Auth::Com::ApplicationController
        include ::SurfaceInertiaPage
        include ::AuthenticationModeSwitchGuard
        include ::AuthCeremonyAdmission

        AUTHENTICATION_MODE = :guest
        declare_authentication_mode! :guest, no_redirect: true

        def show
          admit_or_render_sign_ceremony!(expected_intent: "sign_in") { render_method_selection! }
        end

        private

        def reject_logged_in_direct_entry!
          render_sign_in_unavailable_while_authenticated
        end

        # Logged-in direct entry is refused; unauthenticated direct entry bridges to Base admission.
        alias handle_logged_in_direct_entry! reject_logged_in_direct_entry!

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
