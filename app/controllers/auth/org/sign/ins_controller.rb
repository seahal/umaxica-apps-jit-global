# typed: false
# frozen_string_literal: true

module Auth
  module Org
    module Sign
      class InsController < ::Auth::Org::ApplicationController
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
          render inertia: true, props: sign_in_entry_props
        end

        # Normal org sign-in starts at Entra and only at Entra: the passkey and
        # secret ceremonies are its second stage and refuse to run without the
        # pending Entra transaction, so listing them here as entry points would
        # offer a door that leads back to this page.
        #
        # Emergency Access is listed separately because it is a different
        # ceremony with a different outcome -- a Restricted Mode session -- not
        # another way to sign in normally.
        #
        # Entra needs the organization's connection before a tenant can be
        # chosen, so its entry posts to the surface ceremony endpoint, which
        # renders one cushion page and only then hands the POST to the OmniAuth
        # request phase. Button wording is governed by
        # docs/reference/third-party-sign-in-button-requirements.md.
        def sign_in_entry_props
          pt = signed_pt_param
          region = params[:ri]
          {
            title: t("sign.org.authentication.new.page_title"),
            description: t("sign.org.authentication.new.description"),
            methods: [
              {
                key: "entra",
                kind: "provider",
                label: t("sign.org.authentication.new.links.entra"),
                href: auth_org_social_entra_session_path(pt: pt, ri: region),
              },
              {
                key: "emergency",
                kind: "link",
                label: t("sign.org.authentication.new.links.emergency"),
                href: new_auth_org_sign_in_emergency_passkey_path(pt: pt, ri: region),
              },
            ],
            # Direct entry only. An RP-initiated ceremony asked for a sign-in, so the page must not
            # offer a detour into sign-up; the same rule governs the reciprocal link on
            # auth/org/sign/ups#show.
            registration_link: if @oidc_authorization_intent.blank?
                                 {
                                   label: t("sign.org.authentication.new.links.registration"),
                                   href: auth_org_sign_up_path(pt: pt, ri: region),
                                 }
                               end,
            # D09 Cancel only: Org has no public Sign Up, so no Switch is offered.
            **sign_entry_exit_forms(switch_to: nil, switch_label: nil),
          }
        end

        # Org has no public Sign Up, so there is no sign-up cycle to check.
        def sign_entry_exit_sign_up_cycle_class = nil

        def sign_entry_exit_cancellation_path = auth_org_sign_cancellation_path(ri: params[:ri])

        def sign_entry_exit_switch_path
          raise ArgumentError, "Org Sign In offers no Switch"
        end
      end
    end
  end
end
