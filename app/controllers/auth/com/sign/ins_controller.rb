# typed: false
# frozen_string_literal: true

module Auth
  module Com
    module Sign
      class InsController < ::Auth::Com::ApplicationController
        include ::SurfaceInertiaPage
        include ::AuthenticationModeSwitchGuard
        include ::AuthCeremonyAdmission
        include ::SignInPhaseBindingControllerSupport

        AUTHENTICATION_MODE = :guest
        declare_authentication_mode! :guest, no_redirect: true

        before_action -> {
          enforce_sign_in_phase_binding!(expected_phase: "PRIMARY_PENDING") if params[:entry_ref].blank?
        }

        def show
          admit_or_render_sign_ceremony!(expected_intent: auth_ceremony_entry_intent) { render_method_selection! }
        end

        private

        def auth_ceremony_entry_intent = "sign_in"

        def render_method_selection!
          render inertia: "auth/com/sign_ins/new", props: sign_in_method_props
        end

        # The com surface offers no social provider hand-off, so the list is empty rather than a
        # set of buttons React would have to hide.
        def sign_in_method_props
          pt = signed_pt_param

          {
            title: t("sign.com.authentication.new.page_title"),
            cancel_label: t("actions.cancel"),
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
          binding = sign_in_flow_binding_params(auth_ceremony_local_sign_in_flow, phase: "PRIMARY_PENDING")
          [
            {
              key: "email",
              label: t("sign.com.authentication.new.links.email"),
              href: new_auth_com_sign_in_email_path(ri: params[:ri], pt: pt, **binding),
            },
            {
              key: "passkey",
              label: t("sign.com.authentication.new.links.passkey"),
              href: new_auth_com_sign_in_passkey_path(ri: params[:ri], pt: pt, **binding),
            },
          ]
        end
      end
    end
  end
end
