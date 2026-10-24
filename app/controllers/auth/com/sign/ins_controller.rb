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
        include ::SignEntryExit

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
            description: t("sign.com.authentication.new.description"),
            methods: sign_in_method_links(pt),
            social_providers: [],
            registration_link: registration_link(pt),
            **sign_entry_exit_forms(
              switch_to: "sign_up", switch_label: t("sign.com.authentication.new.links.registration"),
            ),
          }
        end

        # A local entry keeps its link to Sign Up; an OIDC-bound page moves only through Switch.
        def registration_link(pt)
          return nil if sign_entry_parent_bound?

          {
            key: "registration",
            label: t("sign.com.authentication.new.links.registration"),
            href: auth_com_sign_up_sentry_path(ri: params[:ri], pt: pt),
          }
        end

        def sign_entry_exit_sign_up_cycle_class = VisitorSignUpFlow

        def sign_entry_exit_cancellation_path = auth_com_sign_cancellation_path(ri: params[:ri])

        def sign_entry_exit_switch_path = auth_com_sign_switch_path(ri: params[:ri])

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
          ]
        end
      end
    end
  end
end
